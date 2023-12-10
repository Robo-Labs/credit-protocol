import pytest
from brownie import config
from brownie import Contract
from brownie import interface, project, accounts

@pytest.fixture
def amount():
    yield 10000

@pytest.fixture
def loanInfo(borrower, usdc, amount):
    zeroAddress = '0x0000000000000000000000000000000000000000'
    loan = [borrower, usdc, False, zeroAddress , 0 , amount/2, amount, 0, [amount/2, amount/2], [1699974055 + 604800*100, 1699974055 + 604800*200], 1000, 0 ,3600 ,500, 2 ]
    yield loan

@pytest.fixture
def loanInfoCollateral(borrower, usdc, weth, amount):
    loan = [borrower, usdc, True, weth , amount , amount/2, amount, 0, [amount/2, amount/2], [1699974055 + 604800*100, 1699974055 + 604800*200], 1000, 0 ,3600 ,500, 2 ]
    yield loan


@pytest.fixture
def factory_contract():
    yield  project.CreditProtocolProject.PoolFactory

@pytest.fixture
def loan_contract():
    yield  project.CreditProtocolProject.LendingPool

@pytest.fixture
def token_contract():
    yield  project.CreditProtocolProject.Token

@pytest.fixture
def lock_contract():
    yield  project.CreditProtocolProject.LockingContract

@pytest.fixture
def market_contract():
    yield  project.CreditProtocolProject.Market


@pytest.fixture
def market(market_contract, factory,  gov ):
    market = market_contract.deploy(factory, 100, gov, {'from' : gov})
    yield market

@pytest.fixture
def factory(factory_contract, gov):
    factory = factory_contract.deploy(gov, {'from' : gov})
    yield factory

@pytest.fixture
def token(token_contract, gov, backer):
    token = token_contract.deploy("test", "tst", gov, {'from' : gov})
    token.mint(backer, 10000, {'from' : gov})
    yield token
    


@pytest.fixture
def locker(lock_contract, gov, factory, token, backer):
    locker = lock_contract.deploy(gov, {'from' : gov})
    locker.initialise(factory, token, {'from' : gov})
    factory.setLockingContract(locker, {'from' : gov})

    yield locker
    

@pytest.fixture
def gov(accounts):
    yield accounts[1]

@pytest.fixture
def lender(accounts, usdc, whale, amount):
    usdc.transfer(accounts[0], amount, {'from' : whale} )

    yield accounts[0]

@pytest.fixture
def borrower(accounts, usdc, whale, weth, wethWhale, amount):
    weth.transfer(accounts[2], amount*2, {'from' : wethWhale} )
    usdc.transfer(accounts[2], amount*2, {'from' : whale} )

    yield accounts[2]

@pytest.fixture
def backer(accounts):
    yield accounts[3]

@pytest.fixture
def bidder(accounts):
    yield accounts[4]


@pytest.fixture
def wethWhale(accounts):
    yield accounts.at("0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E", force=True)


@pytest.fixture
def whale(accounts):
    yield accounts.at("0xcEe284F754E854890e311e3280b767F80797180d", force=True)

@pytest.fixture
def usdc():
    yield interface.IERC20("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")    

@pytest.fixture
def weth():
    yield interface.IERC20("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")    

# Function scoped isolation fixture to enable xdist.
# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(scope="function", autouse=True)
def shared_setup(fn_isolation):
    pass