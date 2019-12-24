pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./HitchensUnorderedAddressSet.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint256;
    using HitchensUnorderedAddressSetLib for HitchensUnorderedAddressSetLib.Set;
    HitchensUnorderedAddressSetLib.Set openGameRequests;
    uint public constant expiryDuration = 1 hours;

    event FundsTransferedToOwnerEvent(address indexed owner, uint256 amount);
    event LogWithdrawEvent(address indexed sender, uint256 amountDrawn);
    constructor(bool _pausable) Pausable(_pausable) public {}

    enum Move{NoMove, Rock, Paper, Scissors}

    mapping(bytes32 => address) public commits;
    mapping(address => uint256) public players;

    mapping(address => Game) public games;

    struct Game {
        address player2;
        uint256 amount;
        bool isStarted;
        bool isAccepted;
        uint gameStartedBlockNumber;
        address winner;

        Move movePlayer1;
        Move movePlayer2;
    }

    

//*********************** Functions for the game creator ******************************************************** */

    //Open a new game wait for an opponent
    function openNewGame() public payable whenRunning{
        address key = msg.sender;
        openGameRequests.insert(key); // Note that this will fail automatically if the key already exists.
        Game storage game = games[key];
        game.amount = msg.value;
        game.isStarted = false;
    }

    // poll for candidates
    function checkCandidateOpponent() public view returns (address){
        Game storage game = games[msg.sender];
        return game.player2;
    }

    //If after polling, there is a potential candidate, accept the challenge and make the move.
    function acceptAndStartGame(bytes32 moveHash) public {
        Game storage game = games[msg.sender];
        game.isAccepted = true;
        commits[moveHash] = msg.sender;
    }

    //If after polling, there is a nasty candidate, decline, (add him to blacklist.)
    function declineTheRequest() public {
        Game storage game = games[msg.sender];
        game.isAccepted = false;
        game.player2 = address(0);
    }
//********************************************************************************************************************** */


//*********************** Functions for the candidate opponent ******************************************************** */

    //Get available games
    function getOpenGames() public whenRunning returns (bytes32[] memory) {
           //iterate over openGameRequests
           //return a list of addreses
    }

    //Request to join an open game someone created with their address
    function requestToJoinGame(address addr) public payable whenRunning{
        //check if msg.value is same as requested
        //check game.player2 is empty
        Game storage game = games[addr];
        game.player2 = msg.sender;
    }

    // poll if game is accepted
    function checkIfGameIsAccepted(address addr) public view whenRunning returns (bool){
        Game storage game = games[addr];
        return game.isAccepted;
    }

    //After polling, when game is accepted, player2 joins the game by his moves hash, game is offically started.
    function joinToAcceptedGame(bytes32 moveHash, address addressGameCreator) public whenRunning{
        Game storage game = games[addressGameCreator];
        require(game.player2 == msg.sender, "Challange should be accepted to join");
        require(game.isAccepted, "Challange should be accepted to join");
        require(moveHash > 0, "Hash can not be zero");
        game.gameStartedBlockNumber = block.number;
        commits[moveHash] = addressGameCreator;
        game.isStarted = true;
    }

//********************************************************************************************************************** */

    //after polling, if game is started reveal your hand
    function reveal(Move move, bytes32 salt) public payable whenRunning returns (bool) {
        require(salt > 0, "salt should not be empty");
        bytes32 moveHash = calculateMoveHash(move, salt);
        address gameCreatorAddress = commits[moveHash];
        require(gameCreatorAddress != address(0), "claimed hash should exist");
        Game storage game = games[gameCreatorAddress];
        require(game.gameStartedBlockNumber < block.number, "only reveal if commit is mined");
        require(game.winner == address(0), "winner is not settled yet");

        if(game.player2 == msg.sender){
            game.movePlayer2 = move;
        }
        else if(gameCreatorAddress == msg.sender){
            game.movePlayer1 = move;
        }
        else {
            revert("game should belong to the sender");
        }

        address winner = tryToSettle(game.movePlayer1, game.movePlayer2, gameCreatorAddress, game.player2);
        if(winner != address(0)){
            game.winner = winner;
            //do accounting
            //when to remove account?
            openGameRequests.remove(gameCreatorAddress);
            return true;
        }
        return false;
    }

    function tryToSettle(Move moverPlayer1, Move moverPlayer2, address player1, address player2) public view returns (address){
        //compare enums of both players
        //both should exist
        return address(0);
    }

    function calculateMoveHash(Move move, bytes32 salt) public pure returns (bytes32){
        require(salt > 0, "salt should not be empty");
        return keccak256(abi.encodePacked(move, salt));
    }

    function withdraw(uint256 amount) public whenRunning {
        require (amount > 0, "Withdraw amount should be higher than 0");
        uint256 balanceSender = players[msg.sender];
        players[msg.sender] = balanceSender.sub(amount);
        emit LogWithdrawEvent(msg.sender, amount);
        (bool success, ) = msg.sender.call.value(amount)("");
        require(success, "Transfer failed.");
    }

    function transferFunds() public whenKilled onlyOwner {
        uint256 amount = address(this).balance;
        emit FundsTransferedToOwnerEvent(msg.sender, amount);
        (bool success, ) = msg.sender.call.value(amount)("");
        require(success, "Transfer failed.");
    }

    function isExpired(uint expiryTime) public view returns (bool) {
        return now >= expiryTime;
    }
}