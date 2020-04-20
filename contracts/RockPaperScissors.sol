pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./HitchensUnorderedAddressSet.sol";

contract RockPaperScissors is Pausable {

    mapping(address => uint256) public players;
    mapping(address => Game) public games;
    enum Move{NoMove, Rock, Paper, Scissors}

    struct Game {
            uint256 amount;   //zero amount means game ended
            Move movePlayer2; //means game started
            address player2; //means game accepted
            uint gameStartedBlockNumber;
            bytes32 moveHash; //
    }

    function createNewGame(bytes32 moveHash) public payable whenRunning{
        //save amountP1 and moveHash
        address key = msg.sender;
        Game storage game = games[key];
        game.amount = msg.value;
        game.moveHash = moveHash;
        //add money to account
    }

    function joinGame(Move movePlayer2, address addressPlayer1) public payable whenRunning{
        Game storage game = games[addressPlayer1];
        require(msg.value == game.amount, "amount should be same");
        game.movePlayer2 = movePlayer2;
        game.player2 = msg.sender;
    }

    function revealCalculate(bytes32 salt, Move movePlayer1) public whenRunning{
        Game storage game = games[msg.sender];
        require(game.player2 != address(0), "Game shoud be started");
        require(salt > 0, "salt should not be empty");
        require(calculateMoveHash(movePlayer1, salt) == game.moveHash, "Hashes dont match");
        //decideWinner(movePlain1, movePlain2)
        //add money to winners account

        // Game storage game = games[addressGameCreator];
        // require(game.player2 == msg.sender, "Challange should be accepted to join");
        // require(game.isAccepted, "Challange should be accepted to join");
        // require(moveHash > 0, "Hash can not be zero");
        // game.gameStartedBlockNumber = block.number;
        // commits[moveHash] = addressGameCreator;
        // game.isStarted = true;
    }

    function calculateMoveHash(Move move, bytes32 salt) public pure returns (bytes32){
        require(salt > 0, "salt should not be empty");
        return keccak256(abi.encodePacked(move, salt));
    }

    function rejectPlayer() public whenRunning{
        //set movePlayer2 and player2 null
    }
}