import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_lock(accounts, usdc, factory, locker, token, borrower, backer, lender, loan_contract, loanInfo, amount) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    lockAmt = 10000
    startingBal = token.balanceOf(backer)

    token.approve(locker, lockAmt, {'from' : backer})
    locker.lockTokens(lockAmt, 604800*2, {'from' : backer})
    assert token.balanceOf(backer) == startingBal - lockAmt
    assert locker.totalBacked(backer) == 0 
    assert locker.totalLocked(backer) == 10000
    
    with brownie.reverts() : 
        locker.redeemLocked(0, {'from' : backer})

    chain.sleep(604800*3)
    chain.mine(1)

    locker.redeemLocked(0, {'from' : backer})

    assert token.balanceOf(backer) == startingBal

