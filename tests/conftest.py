import pytest
from brownie import config
from brownie import Contract
from brownie import interface, project, accounts

@pytest.fixture
def factory_contract():
    yield  project.CreditProtocol.poolFactory

@pytest.fixture
def factory(factory_contract, gov):
    factory = factory_contract.deploy({'from' : gov})

@pytest.fixture
def gov(accounts):
    yield accounts[1]

@pytest.fixture
def lender(accounts):
    yield accounts[0]

@pytest.fixture
def borrower(accounts):
    yield accounts[2]

@pytest.fixture
def whale(accounts):
    yield accounts.at("0x7601630eC802952ba1ED2B6e4db16F699A0a5A87")

@pytest.fixture
def usdc():
    yield interface.IERC20Extended("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")    

