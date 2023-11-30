import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_collateral_loan(accounts, usdc, weth, factory, locker, token, borrower, backer, lender, loan_contract, loanInfoCollateral, amount) : 
    weth.approve(factory, amount, {'from' : borrower})

    factory.proposeLoan(loanInfoCollateral , {'from' : borrower})
    # TO DO - Check Collateral Transferred Successfully 
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


    usdc.approve(loan, amtOwed * 2, {'from' : borrower})
    nPayments = loanInfoCollateral[-1]

    collateralBalance = weth.balanceOf(loan)
    collateralBalBorrwoer = weth.balanceOf(borrower)

    for i in range(nPayments):
        tx = loan.repayNext({'from' : borrower})
        assert (loan.principleRepaid() + loan.interestEarned() + loan.latePayments()) == borrowerBal + amount - usdc.balanceOf(borrower)


    assert loan.loanFinal()
    amtOwed = loan.calcTotalDue()
    assert amtOwed == 0
    loan.withdraw(0, {'from' : lender})
    assert usdc.balanceOf(lender) >= lenderBal
    
    with brownie.reverts(): 
        loan.triggerDefault({'from' : lender})

    loan.triggerFinal({'from' : lender})

    assert weth.balanceOf(borrower) == collateralBalance + collateralBalBorrwoer
    assert locker.totalBacked(backer) == 0 
    assert locker.totalLocked(backer) == 10000

    # TO DO - Check Collateral Unlocked Successfully 

def test_collateral_default(accounts, usdc, weth, factory, locker, token, borrower, backer, lender, loan_contract, loanInfoCollateral, amount) : 
    weth.approve(factory, amount, {'from' : borrower})

    factory.proposeLoan(loanInfoCollateral , {'from' : borrower})
    # TO DO - Check Collateral Transferred Successfully 
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

    collateralBalance = weth.balanceOf(loan)
    collateralLender = weth.balanceOf(lender)

    chain.sleep(loanInfoCollateral[9][-1])
    chain.mine(1)

    assert loan.hasDefaulted() 
    loan.triggerDefault({'from' : lender})
    assert token.balanceOf(loan) == 10000

    with brownie.reverts(): 
        loan.triggerDefault({'from' : lender})


    loan.claimDefaultBonus(0, {'from' : lender})

    assert token.balanceOf(lender) == 10000
    assert locker.totalBacked(backer) == 0 
    assert locker.totalLocked(backer) == 0

    assert weth.balanceOf(lender) == collateralBalance + collateralLender
    # TO DO - Check Collateral Unlocked Successfully 
    