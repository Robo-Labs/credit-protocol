pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IFactory { 
    function isLoan(address _loan) external view returns(bool);
}

interface ILoan {
    function token() external view returns(address);
    function tokenId() external view returns(uint256);
    function fractionalize(uint256 _tokenIn, uint256 _amountLent) external;
    function deposits(uint256 _tokenId) external view returns(uint256);
    function withdrawals(uint256 _tokenId) external view returns(uint256);
    function withdraw(uint256 _tokenId) external; 
    function ownerOf(uint256 _tokenId) external view returns(address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transfer(address to, uint256 tokenId) external;

}

contract Market is ReentrancyGuard {

    struct orderInfo {
        uint256 price; 
        uint256 amount; 
        uint256 tokenId;
        uint256 maxWithdrawn;
        address user;
        bool bid;
        address loan;
        address token;
    }
    address public factory;
    address public governance;
    uint256 public protocolFee;
    uint256 constant decimalAdj = 10000;
    uint256 public orderNumber;

    mapping(address => uint256) public tokensOwed;
    mapping(address => uint256) public debtOwed;
    mapping(uint256 => orderInfo) public orders;

    constructor(address _factory, uint256 _protocolFee, address _governance) {
        factory = _factory;
        protocolFee = _protocolFee;
        governance = _governance;
    }
    
    modifier onlyGov() {
        require(msg.sender == governance);
        _;

    }

    function isLoan(address _loan) public view returns(bool) {
        return(IFactory(factory).isLoan(_loan));
    }

    function removeOrder(uint256 _orderNumber) external nonReentrant {
        orderInfo memory order = orders[_orderNumber];
        require(order.user == msg.sender);
        if (order.bid) { 
            uint256 total = order.price * order.amount / decimalAdj;
            IERC20(order.token).transfer(msg.sender, total);
        } else {
            ILoan(order.loan).transferFrom(address(this), msg.sender, order.tokenId);
        }
        orders[_orderNumber].amount = 0;
    }

    // Buying Token
    function placeBid(uint256 _price,  uint256 _amount, uint256 _maxWithdrawn, address _token, address _loan) external nonReentrant {
        // TO DO - transfer token / add to order book + check if matches / add data tracking how many assets user entitled to 
        uint256 total = _price * _amount / decimalAdj;
        IERC20(_token).transferFrom(msg.sender, address(this), total);

        orderInfo memory newOrder = orderInfo({
            price : _price,
            amount : _amount,
            tokenId : 0,
            maxWithdrawn : _maxWithdrawn,
            user : msg.sender,
            bid : true,
            loan : _loan,
            token : _token
        });

        orders[orderNumber] = newOrder;
        orderNumber += 1;

    } 

    function matchBid(uint256 _bidNumber, uint256 _amount, uint256 _tokenId) external nonReentrant {
        orderInfo memory bid = orders[_bidNumber];
        IERC20 token = IERC20(bid.token);
        uint256 price = bid.price;
        uint256 total = price * _amount / decimalAdj;

        require(bid.bid);
        require(_amount <= bid.amount);
        require(_amount <= ILoan(bid.loan).deposits(_tokenId));
        require(bid.maxWithdrawn >= (ILoan(bid.loan).withdrawals(_tokenId) * _amount / bid.amount) );
        ILoan(bid.loan).transferFrom(msg.sender, address(this), _tokenId);

        if (_amount < ILoan(bid.loan).deposits(_tokenId)) {
            // We need to "Fractionalize to match exact amounts & then send back unmatched amounts

            ILoan(bid.loan).fractionalize(_tokenId, _amount);
            ILoan(bid.loan).transferFrom(address(this), bid.user, ILoan(bid.loan).tokenId() - 2);
            ILoan(bid.loan).transferFrom(address(this), msg.sender, ILoan(bid.loan).tokenId() - 1);
        } else {
            ILoan(bid.loan).transferFrom(address(this), bid.user, _tokenId);
        }



        token.transfer(msg.sender, total );
        orders[_bidNumber].amount = orders[_bidNumber].amount - _amount;

    }

    // Selling Token
    function placeAsk(uint256 _price, uint256 _amount  ,address _token, address _loan, uint256 _tokenId) external nonReentrant {
        uint256 loanAmount = ILoan(_loan).deposits(_tokenId);
        require(ILoan(_loan).ownerOf(_tokenId) == msg.sender);
        ILoan(_loan).transferFrom(msg.sender, address(this), _tokenId);

        orderInfo memory newOrder = orderInfo({
            price : _price,
            amount : _amount,
            tokenId : _tokenId,
            maxWithdrawn : 0,
            user : msg.sender,
            bid : false,
            loan : _loan,
            token : _token
        });

        orders[orderNumber] = newOrder;
        orderNumber += 1;
    } 

    function matchAsk(uint256 _askNumber,  uint256 _amount) external nonReentrant {
        orderInfo memory ask = orders[_askNumber];
        IERC20 token = IERC20(ask.token);
        uint256 price = ask.price;
        uint256 total = price * _amount / decimalAdj;
        uint256 _tokenId = ask.tokenId;
        require(!ask.bid);
        require(_amount <= ask.amount);
        require(_amount <= ILoan(ask.loan).deposits(ask.tokenId));

        token.transferFrom(msg.sender, ask.user, total);

        if (_amount <  ILoan(ask.loan).deposits(ask.tokenId)) {
            // We need to "Fractionalize to match exact amounts & then send back unmatched amounts

            ILoan(ask.loan).fractionalize(_tokenId, _amount);
            ILoan(ask.loan).transferFrom(address(this), msg.sender, ILoan(ask.loan).tokenId() - 2);
            //loan.transfer(ask.user, loan.tokenId());
        } else {
            ILoan(ask.loan).transferFrom(address(this), msg.sender, _tokenId);
        }

        //token.transferFrom(ask.user, ask.user, total);
        orders[_askNumber].amount = orders[_askNumber].amount - _amount;
        orders[_askNumber].tokenId = ILoan(ask.loan).tokenId() - 1;



    }

}
