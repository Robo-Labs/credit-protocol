import pytest
from brownie import config
from brownie import Contract
from brownie import interface, project, accounts

@pytest.fixture
def factory_contract():
    yield  project.CreditProtocol.PoolFactory

@pytest.fixture
def token_contract():
    yield  project.CreditProtocol.Token

@pytest.fixture
def lock_contract():
    yield  project.CreditProtocol.LockingContract

@pytest.fixture
def factory(factory_contract, gov):
    factory = factory_contract.deploy({'from' : gov})

@pytest.fixture
def token(token_contract, gov, backer):
    token = token_contract.deploy("test", "tst", gov, {'from' : gov})
    token.mint(backer, 10000, {'from' : gov})
    

@pytest.fixture
def locker(lock_contract, gov, factory, token, backer):
    locker = lock_contract.deploy(gov, {'from' : gov})
    locker.initialise(factory, token, {'from' : gov})
    token.approve(locker, 10000, {'from' : locker})
    locker.lockTokens(10000, 10000, {'from' : locker})
    

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
def backer(accounts):
    yield accounts[3]

@pytest.fixture
def whale(accounts):
    yield accounts.at("0x7601630eC802952ba1ED2B6e4db16F699A0a5A87")

@pytest.fixture
def usdc():
    yield interface.IERC20("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")    

