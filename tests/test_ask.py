import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_ask(accounts, usdc, market, factory, locker, token, bidder, whale, borrower, backer, lender, loan_contract, loanInfo, amount) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    token.approve(locker, 10000, {'from' : backer})
    locker.lockTokens(10000, 604800*2, {'from' : backer})
    factory.backLoan(10000, 0, {'from' : backer})
    # Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # Lend from users 
    loan = loan_contract.at(factory.loanAddress(0))
    # Borrow & Repay 
    lenderBal = usdc.balanceOf(lender)
    borrowerBal = usdc.balanceOf(borrower)
    usdc.approve(loan, amount, {'from' : lender})
    loan.deposit(amount, {'from' : lender})
    assert usdc.balanceOf(lender) == lenderBal - amount
    assert usdc.balanceOf(loan) == amount
    loan.withdrawLentFunds({'from' : borrower})
    assert usdc.balanceOf(borrower) == borrowerBal + amount
    amtOwed = loan.calcTotalDue()
    assert amtOwed >= amount
    chain.sleep(1000)
    chain.mine(10)



    usdc.transfer(bidder, amount*2, {'from' : whale} )
    usdc.approve(market, amount, {'from' : bidder})


    bidderBal = usdc.balanceOf(bidder)
    loan.approve(market, 0, {'from' : lender})

    market.placeAsk(10000, amount, usdc, loan, 0, {'from' : lender})
    lenderBal = usdc.balanceOf(lender)
    market.matchAsk(0, amount, {'from' : bidder})

    assert usdc.balanceOf(bidder) == bidderBal - amount
    assert usdc.balanceOf(lender) == lenderBal + amount
    assert loan.ownerOf(0) == bidder


def test_ask_partial(accounts, usdc, market, factory, locker, token, bidder, whale, borrower, backer, lender, loan_contract, loanInfo, amount) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    token.approve(locker, 10000, {'from' : backer})
    locker.lockTokens(10000, 604800*2, {'from' : backer})
    factory.backLoan(10000, 0, {'from' : backer})
    # Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # Lend from users 
    loan = loan_contract.at(factory.loanAddress(0))
    # Borrow & Repay 
    lenderBal = usdc.balanceOf(lender)
    borrowerBal = usdc.balanceOf(borrower)
    usdc.approve(loan, amount, {'from' : lender})
    loan.deposit(amount, {'from' : lender})
    assert usdc.balanceOf(lender) == lenderBal - amount
    assert usdc.balanceOf(loan) == amount
    loan.withdrawLentFunds({'from' : borrower})
    assert usdc.balanceOf(borrower) == borrowerBal + amount
    amtOwed = loan.calcTotalDue()
    assert amtOwed >= amount
    chain.sleep(1000)
    chain.mine(10)


    usdc.transfer(bidder, amount*2, {'from' : whale} )
    usdc.approve(market, amount, {'from' : bidder})

    bidderBal = usdc.balanceOf(bidder)
    loan.approve(market, 0, {'from' : lender})

    market.placeAsk(10000, amount, usdc, loan, 0, {'from' : lender})
    lenderBal = usdc.balanceOf(lender)
    market.matchAsk(0, amount / 2, {'from' : bidder})

    assert usdc.balanceOf(bidder) == bidderBal - amount / 2
    assert usdc.balanceOf(lender) == lenderBal + amount / 2
    assert loan.ownerOf(1) == bidder


def test_remove_ask(accounts, usdc, market, factory, locker, token, bidder, whale, borrower, backer, lender, loan_contract, loanInfo, amount) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    token.approve(locker, 10000, {'from' : backer})
    locker.lockTokens(10000, 604800*2, {'from' : backer})
    factory.backLoan(10000, 0, {'from' : backer})
    # Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # Lend from users 
    loan = loan_contract.at(factory.loanAddress(0))
    # Borrow & Repay 
    lenderBal = usdc.balanceOf(lender)
    borrowerBal = usdc.balanceOf(borrower)
    usdc.approve(loan, amount, {'from' : lender})
    loan.deposit(amount, {'from' : lender})
    assert usdc.balanceOf(lender) == lenderBal - amount
    assert usdc.balanceOf(loan) == amount
    loan.withdrawLentFunds({'from' : borrower})
    assert usdc.balanceOf(borrower) == borrowerBal + amount
    amtOwed = loan.calcTotalDue()
    assert amtOwed >= amount
    chain.sleep(1000)
    chain.mine(10)


    usdc.transfer(bidder, amount*2, {'from' : whale} )
    usdc.approve(market, amount, {'from' : bidder})

    bidderBal = usdc.balanceOf(bidder)
    loan.approve(market, 0, {'from' : lender})

    market.placeAsk(10000, amount, usdc, loan, 0, {'from' : lender})
    lenderBal = usdc.balanceOf(lender)
    market.removeOrder(0, {'from' : lender})

    assert loan.ownerOf(0) == lender

    with brownie.reverts(): 
        market.matchAsk(0, amount, {'from' : bidder})
