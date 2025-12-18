[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/KXriINDx)

# What is BitVote?
The current governance model for Bitcoin development relies on an informal process of rough consensus, where improvements are debated across fragmented mailing lists and forums for extended periods of time. While this conservatism protects the network’s security in certain senses, it creates significant opacity regarding true community sentiment and raises the amount of effort it takes to propose new ideas. There is currently no verifiable, decentralized method to measure the popularity of a proposal, leaving the selected Bitcoin Improvement Protocol (BIP) Editors the responsibility of guessing whether an idea has the broad community support necessary to move forward. This process can lead to wasted effort, and contentious disputes.

BitVote attempts to solve this for the Bitcoin by providing a decentralized, trustless voting platform built on the Stacks Layer 2 blockchain. By anchoring voting logic in immutable smart contracts while handling discovery off-chain, BitVote offers a secure signaling layer that aligns with Bitcoin’s ethos of censorship resistance. The system employs a small fees and level-up mechanism to filter spam organically and utilizes optimistic batch cleanups to minimize gas costs, enabling the Bitcoin community to signal clear, verifiable consensus on protocol upgrades without altering the base layer or relying on centralized intermediaries.

# To run the code:

**Note:** this is a mockup, incomplete version of the discussed system.

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
brew install clarinet
```

If you are installing clarinet without homebrew, check out the official [Clarinet instillation section][https://docs.stacks.co/get-started/developer-quickstart#set-up-your-developer-environment] for more help.

Then, go to Code/Settings and change the name of Testnet-template.toml to be Testnet.toml and add your mnemonic to that file. From the Code directory, run `clarinet deployments apply --testnet` to deploy the contract once.

To see the website, run `python app.py` and open localhost:5000.

If you are re-running this after the initial set-up, run `source venv/bin/activate` and `python app.py` only.

When you are done, run `deactivate` in the terminal to turn off the virtual environment.
