// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.13;

contract Auction {
    address public supplier;
    address public cur_buyer;

    //uint256 public start_time;
    uint256 public end_time;
    uint256 public duration;
    uint256 public cur_price;
    bool public is_over;

    mapping(address => uint256) public history;

    // Auction Item Description
    struct Goods {
        uint256 starting_price;
        //uint256 final_price;
        address _supplier;
        string descriptions;
    }

    Goods public cur_good;

    // Events and Errors
    event Set_goods(address indexed _supplier, uint256 starting_price, string des);
    event Set_price(address indexed buyer, uint256 possible_price);
    event Refund_money(address indexed buyer, uint256 last_price);
    event Over(address indexed buyer, uint256 final_price);
    error Price_denied(uint256 _cur_price);

    // Determine if you can make a bid
    modifier is_buyer() {
        require(msg.sender != supplier, "Permission denied! You're the supplier.");
        _;
    }

    modifier is_before_end_time() {
        require(block.timestamp < end_time, "The auction is over, so please come back another time.");
        _;
    }

    constructor() {
        supplier = msg.sender;
        is_over = false;
    }

    modifier is_supplier() {
        require(msg.sender == supplier, "Permission denied! You're the buyer.");
        _;
    }

    function set_goods(uint256 _duration, uint256 _starting_price, string _des) public is_supplier {
        // calculate end time
        duration = _duration;
        end_time = block.timestamp + _duration;

        // set info
        cur_good._supplier = msg.sender;
        cur_good.starting_price = _starting_price;
        cur_good.descriptions = _des;

        // Set the current maximum price and "buyer" (actually the supplier)
        cur_buyer = msg.sender;
        cur_price = _starting_price;
    }

    function set_price() public payable is_before_end_time is_buyer {
        // Determining if the price is high enough
        if (msg.value <= cur_price) {
            revert Price_denied(cur_price);
        }

        history[cur_buyer] += cur_price;

        // update price
        cur_buyer = msg.sender;
        cur_price = msg.value;

        emit Set_price(msg.sender, msg.value);
    }

    // Since the auction needs to be closed, only the supplier can operate it.
    // At the same time, the auction cannot be ended early.
    modifier is_after_end_time() { 
        require(block.timestamp >= end_time, "Auction is in progress, please do not end early.");
        _;
    }

    function over() public is_supplier is_after_end_time {
        // cannot end twice
        require(!is_over, "The auction has been closed.");

        is_over = true;
        emit Over(cur_buyer, cur_price);

        // Passing on the proceeds of the auction.
        payable(supplier).transfer(cur_price);
    }

    // Virtual buyers are excluded because they are set as suppliers at the beginning.
    function refund_money() public is_buyer {
        uint256 refund = history[msg.sender];

        require(refund > 0, "No refunds are required!");
        history[msg.sender] = 0;

        require(msg.sender != supplier, "Permission denied! You're the supplier.");
        payable(msg.sender).transfer(refund);
        emit Refund_money(msg.sender, refund);
    }
}