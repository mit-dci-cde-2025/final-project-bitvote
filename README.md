[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/KXriINDx)


# To Set Up:

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