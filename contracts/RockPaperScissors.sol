pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract RockPaperScissors is Pausable {
    using SafeMath for uint256;
    uint public constant expiryDuration = 8 hours;
    constructor(bool _pausable) Pausable(_pausable) public {}

    enum Move{Rock, Paper, Scissors}

    mapping(bytes32 => Commit) public commits;
    struct Commit {
        address sender;
        uint256 amount;
        uint expiryTime;
        bool isRevealed;
    }

    mapping(address => Player) public players;
    struct Player {
        uint256 balance;
        uint256 lastBetAmount;
        bytes32 lastMoveHash;
    }

    mapping(bytes32 => Game) public games;
    struct Game {
        address player2;
        uint256 amount;
    }

    function startGame(address player2) public payable{
        Game storage game = games[msg.sender];
        game.player2 = player2;
        game.amount = msg.value;
    }

    function startGame(bytes32 moveHash) public payable{
        createPlayer(msg.sender, moveHash, msg.value);
        createCommit(moveHash);
    }

    function createCommit(bytes32 moveHash) public payable whenRunning returns (Commit memory){
        require(moveHash > 0, "passwordHash should not be empty");
        Commit storage commit = commits[moveHash];
        commit.sender = msg.sender;
        commit.amount = msg.value;
        commit.expiryTime = now.add(expiryDuration);
        return commit;
    }

    function createPlayer(address addr, bytes32 moveHash, uint256 amount) public payable whenRunning returns (Player memory){
        require(moveHash > 0, "moveHash should not be empty");
        Player storage player = players[addr];
        player.lastMoveHash = moveHash;
        player.lastBetAmount = amount;
        return player;
    }

    function reveal(Move move, bytes32 salt) public payable whenRunning {
        require(salt > 0, "salt should not be empty");
        bytes32 moveHash = calculateMoveHash(move, salt);
        Commit storage commit = commits[moveHash];
        address sender = commit.sender;
        require(sender != address(0), "commit should exist");
    }

    function calculateMoveHash(Move move, bytes32 salt) public view returns (bytes32){
        require(salt > 0, "salt should not be empty");
        return keccak256(abi.encodePacked(move, salt));
    }








    function withdraw(bytes32 passw) public whenRunning {
        bytes32 passwordHash = hashPasswords(msg.sender, passw);
        Account storage account = accounts[passwordHash];
        uint256 amount = account.amount;

        require(amount > 0, "account should exist");
        require(!isExpired(account.expiryTime), "account should not be expired");

        emit WithdrawEvent(msg.sender, amount, passwordHash);
        account.amount = 0;
        account.expiryTime = 0;
        
        (bool success, ) = msg.sender.call.value(amount)("");
        require(success, "transfer failed.");
    }

    function cancelRockPaperScissors(bytes32 passwordHash) public whenRunning {
        Account storage account = accounts[passwordHash];
        uint256 amount = account.amount;

        require(amount > 0, "account should exist");
        require(account.sender == msg.sender, "only sender can cancel the payment");
        require(isExpired(account.expiryTime), "account should be expired");

        emit WithdrawEvent(msg.sender, amount, passwordHash);
        account.amount = 0;
        account.expiryTime = 0;

        (bool success, ) = msg.sender.call.value(amount)("");
        require(success, "transfer failed.");
    }


    function validateCandidateHash(bytes32 candidateHash, address addr, bytes32 passw) public view returns (bool){
        require(candidateHash > 0, "passwordHash should not be empty");
        require(candidateHash == hashPasswords(addr, passw), "Hashes do not match");
        return true;
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