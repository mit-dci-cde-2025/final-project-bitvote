from flask import Flask, render_template, abort, jsonify
import requests, struct

app = Flask(__name__, template_folder="templates")

NETWORK = 'testnet'
STACKS_RPC_URL = "https://api.testnet.hiro.so" if NETWORK == "testnet" else "http://localhost:20443"
CONTRACT_ADDRESS = "ST1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE"
PROPOSAL_CONTRACT = "proposal-contract-v6"
GOV_TOKEN_CONTRACT = "governance-token-v2"
PROPOSAL_MAP = "proposals"
PROPOSAL_COUNT_VAR = "proposal-count"

def ser_uint(u):
    return bytes([0x01]) + u.to_bytes(16, "big")  # uint128


def ser_tuple(fields):
    out = bytearray()
    out.append(0x0c)
    out += struct.pack(">I", len(fields))
    for name, v in fields.items():
        nb = name.encode("ascii")
        out.append(len(nb))
        out += nb
        out += v
    return bytes(out)


def ser_list(serialized_items):
    out = bytearray()
    out.append(0x0b)
    out += struct.pack(">I", len(serialized_items))
    for item in serialized_items:
        out += item
    return bytes(out)


def hex0x(b):
    return "0x" + b.hex()


def proposal_key_hex(cat_id, index):
    return hex0x(ser_tuple({
        "category-id": ser_uint(cat_id),
        "index": ser_uint(index)
    }))


def parse_clarity(b, i = 0):
    t = b[i]; i += 1
    if t == 0x00:  # int128
        return int.from_bytes(b[i:i+16], "big", signed=True), i + 16
    elif t == 0x01:  # uint128
        return int.from_bytes(b[i:i+16], "big"), i + 16
    elif t == 0x02:  # buffer
        (n,) = struct.unpack(">I", b[i:i+4]); i += 4
        return b[i:i+n], i + n
    elif t == 0x03:  # bool-true
        return True, i
    elif t == 0x04:  # bool-false
        return False, i
    elif t == 0x05:  # standard-principal
        addr_bytes = b[i:i+21]
        return "0x" + addr_bytes.hex(), i + 21
    elif t == 0x06:  # contract-principal
        issuer_bytes = b[i:i+21]; i += 21
        (n,) = struct.unpack(">I", b[i:i+4]); i += 4
        name = b[i:i+n].decode("ascii"); i += n
        return f"0x{issuer_bytes.hex()}.{name}", i
    elif t == 0x07:  # response-ok
        return parse_clarity(b, i)
    elif t == 0x08:  # response-err
        return parse_clarity(b, i)
    elif t == 0x09:  # none
        return None, i
    elif t == 0x0a:  # some
        return parse_clarity(b, i)
    elif t == 0x0c:  # tuple
        (count,) = struct.unpack(">I", b[i:i+4]); i += 4
        d = {}
        for _ in range(count):
            nlen = b[i]; i += 1
            name = b[i:i+nlen].decode("ascii"); i += nlen
            val, i = parse_clarity(b, i)
            d[name] = val
        return d, i
    elif t == 0x0d:  # string-ascii
        (n,) = struct.unpack(">I", b[i:i+4]); i += 4
        s = b[i:i+n].decode("ascii", errors="replace"); i += n
        return s, i 
    elif t == 0x0e:  # string-utf8
        (n,) = struct.unpack(">I", b[i:i+4]); i += 4
        s = b[i:i+n].decode("utf-8", errors="replace"); i += n
        return s, i

    raise ValueError(f"Unsupported Clarity type 0x{t:02x}")


def decode_clarity_hex(h):
    raw = bytes.fromhex(h[2:] if h.startswith("0x") else h)
    return parse_clarity(raw, 0)[0]


def call_read_only(function_name, args=[]):
    url = f"{STACKS_RPC_URL}/v2/contracts/call-read/{CONTRACT_ADDRESS}/{PROPOSAL_CONTRACT}/{function_name}"
    payload = {
        "sender": CONTRACT_ADDRESS,
        "arguments": args
    }
    r = requests.post(url, json=payload)
    if r.status_code != 200:
        print(f"Error calling {function_name}: {r.text}")
        return None
    
    resp = r.json()
    if not resp.get("okay"):
        print(f"Clarity Execution Error: {resp.get('cause')}")
        return None

    return decode_clarity_hex(resp["result"])


def fetch_proposal(cat_id, index):
    url = f"{STACKS_RPC_URL}/v2/map_entry/{CONTRACT_ADDRESS}/{PROPOSAL_CONTRACT}/{PROPOSAL_MAP}"
    key = proposal_key_hex(cat_id, index)

    r = requests.post(url, json=key, timeout=10)
    r.raise_for_status()

    data_hex = r.json()["data"]
    decoded = decode_clarity_hex(data_hex)

    if decoded is None:
        return None

    return decoded


def get_block_height():
    res = call_read_only("get-current-block-height")
    return int(res) if res is not None else 0


def find_and_conclude_stale_proposals():
    block_height = get_block_height()
    cat_count = int(call_read_only("get-category-count") or 0)
    
    stale_proposals = []

    for cat_id in range(1, cat_count + 1):
        count_in_cat = int(call_read_only("get-count-in-category", [hex0x(ser_uint(cat_id))]) or 0)
        
        for idx in range(1, count_in_cat + 1):
            p = fetch_proposal(cat_id, idx)
            if not p: continue

            if p["end-block"] <= block_height: # inactive
                status_res = call_read_only("get-proposal-status", [
                    hex0x(ser_uint(cat_id)), 
                    hex0x(ser_uint(idx))
                ])
                status = int(status_res) if status_res is not None else 2
                
                if status == 2: # undecided
                    stale_proposals.append(ser_tuple({
                        "category-id": ser_uint(cat_id),
                        "index": ser_uint(idx)
                    }))

    return hex0x(ser_list(stale_proposals))
    


############################################################

@app.route("/")
def index():
    block_height = get_block_height()
    active, inactive = [], []
    res = call_read_only("get-category-count")
    cat_count = int(res) if res is not None else 0
    for i in range(1, cat_count + 1):
        res = call_read_only("get-count-in-category", [hex0x(ser_uint(i))])
        prop_count = int(res) if res is not None else 0
        p = fetch_proposal(i, prop_count)
        p['category-id'] = i
        end_block = int(p["end-block"])
        if end_block > block_height:
            active.append(p)
        else:
            inactive.append(p)
    return render_template("index.html", active=active, inactive=inactive,
                           network=NETWORK, block_height = block_height,
                           contract_addr=CONTRACT_ADDRESS,
                           contract_name=GOV_TOKEN_CONTRACT)


@app.route("/proposal/<int:category_id>")
def proposal_detail(category_id):
    res = call_read_only("get-count-in-category", [hex0x(ser_uint(category_id))])
    prop_count = int(res) if res is not None else 0
    proposals = []
    for i in range(1, prop_count + 1):
        p = fetch_proposal(category_id, i)
        if p:
            p['index'] = i
            p['category-id'] = category_id
            proposals.append(p)

    if not proposals:
        abort(404)

    block_height = get_block_height()
    end_block = int(proposals[-1]["end-block"])
    is_active = True if end_block > block_height else False
    status = call_read_only("get-proposal-status", [
        hex0x(ser_uint(category_id)), 
        hex0x(ser_uint(i))
    ])
    proposals.reverse()
        
    return render_template("proposal.html", proposals=proposals, 
                           contract_addr=CONTRACT_ADDRESS,
                           contract_name=PROPOSAL_CONTRACT,
                           network=NETWORK, is_active=is_active,
                           stale=find_and_conclude_stale_proposals(),
                           status=status)

@app.route("/new")
def new_proposal():
    return render_template("new_proposal.html", 
                           contract_addr=CONTRACT_ADDRESS,
                           contract_name=PROPOSAL_CONTRACT,
                           network=NETWORK,
                           stale=find_and_conclude_stale_proposals())


@app.errorhandler(404)
def page_not_found(e):
    return render_template("error.html", error_code=404, message="Page Not Found"), 404

@app.errorhandler(500)
def internal_error(e):
    return render_template("error.html", error_code=500, message="Internal System Error"), 500

@app.route("/<path:path>")
def catch_all_route(path):
    return render_template("error.html", error_code=404, message="Path does not exist"), 404


if __name__ == "__main__":
    app.run(debug=True, port=5000)
