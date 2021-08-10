// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol';
import '@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';
import './CashToken.sol';

contract CashPresale is ReentrancyGuard, Context, Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    using Address for address payable;

    // The token being sold
    IBEP20 public CASH;

    // The rate token
    IBEP20 public rateToken;
    
    address payable public wallet;
    uint256 public startRate;
    uint256 public start;
    uint256 public step;

    mapping(address => bool) internal _supportedTokens;
    mapping(address => uint256) public totalsByTokens;
    uint256 public totalsSold;
    /**
     * event for token purchase logging
     * @param purchaser who paid & got for the tokens
     * @param valueToken address of token for value amount
     * @param value amount paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed valueToken, uint256 value, uint256 amount);

    constructor(
        address _cash,
        address payable _wallet,
        address _rateToken,
        uint256 _startRate,
        uint256 _step,
        uint256 _start,
        address[] memory supportetTokens
    ) public {
        CASH = IBEP20(_cash);
        rateToken = IBEP20(_rateToken);
        wallet = _wallet;
        startRate = _startRate;
        start = _start;
        step = _step;
        for (uint256 index = 0; index < supportetTokens.length; index++) {
            _supportedTokens[supportetTokens[index]] = true;
        }
    }

    function getCurrentRate() public view returns (uint256) {
        if (block.timestamp < start) {
            return step;
        }
        uint256 tdiff = block.timestamp.sub(start).div(7 days);
        return startRate.add(step.mul(tdiff));
    }

    function buyTokens(uint256 _value, address _token) external nonReentrant {
        require(validPurchase(_value, _token));
        IBEP20 token = IBEP20(_token);
        token.safeTransferFrom(_msgSender(), wallet, _value);
        // token.safeTransfer(wallet, _value);
        uint256 amount = _value.div(getCurrentRate()).mul(uint256(10)**uint256(CASH.decimals()));
        totalsByTokens[_token] = totalsByTokens[_token].add(_value);
        totalsSold = totalsSold.add((amount));
        CASH.safeTransfer(_msgSender(), amount);
        emit TokenPurchase(_msgSender(), _token, _value, amount);
    }

    // return true if the transaction can buy tokens
    function validPurchase(uint256 value, address token) internal view returns (bool) {
        bool notSmallAmount = value > 0; // value >= minInvestment;
        return (notSmallAmount && _supportedTokens[token]);
    }

    receive() external payable {
        payable(msg.sender).sendValue(msg.value); // return any direct payments
    }

    function emergencyWithdraw(address _token) external onlyOwner nonReentrant {
        IBEP20(_token).safeTransfer(owner(), IBEP20(_token).balanceOf(address(this)));
    }
}
