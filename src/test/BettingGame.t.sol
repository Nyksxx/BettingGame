// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BettingGame.sol";
import "./mocks/MockVRFCoordinatorV2.sol";
import "./mocks/LinkToken.sol";
import "./utils/Cheats.sol";
import "forge-std/Test.sol";

contract BettingGameTest is Test {
    LinkToken public linkToken;
    MockVRFCoordinatorV2 public vrfCoordinator;
    BettingGame public _bettingGame;
    Cheats internal constant cheats = Cheats(HEVM_ADDRESS);

    uint96 constant FUND_AMOUNT = 1 * 10**18;

    // Initialized as blank, fine for testing
    uint64 subId;
    bytes32 keyHash; // gasLane

    event ReturnedRandomness(uint256[] randomWords);

    function setUp() public {
        linkToken = new LinkToken();
        vrfCoordinator = new MockVRFCoordinatorV2();
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);
        _bettingGame = new BettingGame(
            subId,
            address(vrfCoordinator),
            address(linkToken),
            keyHash
        );
    }

    function testCanRequestRandomness() public {
        uint256 startingRequestId = _bettingGame.s_requestId();
        _bettingGame.requestRandomWords();
        assertTrue(_bettingGame.s_requestId() != startingRequestId);
    }

    function testCanGetRandomResponse() public {
        _bettingGame.requestRandomWords();
        uint256 requestId = _bettingGame.s_requestId();

        uint256[] memory words = getWords(requestId);

        vrfCoordinator.fulfillRandomWords(requestId, address(_bettingGame));
        assertTrue(_bettingGame.s_randomWords(0) == words[0]);
        assertTrue(_bettingGame.s_randomWords(1) == words[1]);
    }

    function getWords(uint256 requestId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory words = new uint256[](_bettingGame.s_numWords());
        for (uint256 i = 0; i < _bettingGame.s_numWords(); i++) {
            words[i] = uint256(keccak256(abi.encode(requestId, i)));
        }
        return words;
    }

    function testDeposit() public {
        _bettingGame.deposit{value: 1 ether}();
        assertTrue(_bettingGame.getBalance(address(this)) == 1 ether);
    }

    function testBet() public {
        _bettingGame.requestRandomWords();
        uint256 requestId = _bettingGame.s_requestId();

        vrfCoordinator.fulfillRandomWords(requestId, address(_bettingGame));

        _bettingGame.deposit{value: 1 ether}();

        uint256 _amount = 0.5 ether;

        _bettingGame.bet(_amount);

        assertTrue(_bettingGame.getBalance(address(this)) == 0.5 ether);
    }

    function testWithdraw() public {
        _bettingGame.deposit{value: 1 ether}();
        _bettingGame.withdraw(1 ether);
        assertTrue(_bettingGame.getBalance(address(this)) == 0 ether);
    }
}
