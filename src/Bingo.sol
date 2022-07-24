//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBase} from "@chainlink/v0.8/VRFConsumerBase.sol";

contract Bingo is Ownable, VRFConsumerBase {
    uint256 public nextGameId;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 internal timeToUnlockCard;

    uint256 internal randomResult;

    struct Player {
        uint256 totalBets;
        uint256 totalGains;
        mapping(bytes32 => bool) isKeyOwner;
        mapping(uint256 => bytes32) gameKey;
        mapping(uint256 => mapping(uint256 => uint256)) board;
        mapping(uint256 => bool) hasJoin;
    }

    struct Game {
        address winner;
        address token;
        uint256 entryPrice;
        uint256 joinDurationTime;
        uint256 turnDuration;
        uint256 gameTotalBets;
    }

    mapping(address => Player) public players;
    mapping(uint256 => Game) public games;
    mapping(uint256 => bytes32) internal gameKey;

    mapping(uint256 => mapping(uint256 => uint256)) gameResult;
    mapping(uint256 => mapping(uint256 => uint256[])) keyResults;

    error InsufficientBalance();
    error EntryDenied();
    error NotGameParticipant();
    event Bet(address indexed player, uint256 bet, uint256 gameId);

    event NewGame(uint256 indexed id, address token, uint256 entryPrice);

    constructor(address _vrfcordinator, address _link)
        VRFConsumerBase(_vrfcordinator, _link)
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)
    }

    /**
    @dev add a new game to play, player could enter this game and receive a new grid to play with
    @param _token, IERC20 token to pay as entry fees
    @param _joinDurationTime , time before the game start
    @param _entryPrice amount to pay as fees for the game
    @param _turn minimum turn the numbers are draws 
    */
    function addNewGame(
        address _token,
        uint256 _entryPrice,
        uint256 _joinDurationTime,
        uint256 _turn
    ) external onlyOwner {
        Game storage game = games[nextGameId];
        game.token = _token;
        game.entryPrice = _entryPrice;
        game.joinDurationTime = block.timestamp + _joinDurationTime;
        game.turnDuration = _turn;

        emit NewGame(nextGameId, _token, _entryPrice);
        unchecked {
            nextGameId++;
        }
    }

    /**
    @dev update entry fees for specific game
    @param _gameId game Id
    @param _price new price for the entry fees
    */
    function setGameEntryPrice(uint256 _gameId, uint256 _price)
        external
        onlyOwner
    {
        games[_gameId].entryPrice = _price;
    }

    /**
    @dev this function allow owner to postpone the date the game starts
    @param _gameId , id of the game owner wants to apply the change
    @param _joinDuration, time to add
     */
    function postPoneGameEntry(uint256 _gameId, uint256 _joinDuration)
        external
        onlyOwner
    {
        games[_gameId].joinDurationTime = _joinDuration;
    }

    /**
    @dev users are able here to pay an entry for the game they would like to
    join, each game is designed to have his own price entry and token for payment method
    @param _gameId Id of the game to join 
    */
    function bet(uint256 _gameId) external returns (bytes32) {
        Game memory game = games[_gameId];
        if (block.timestamp > game.joinDurationTime) {
            revert EntryDenied();
        }
        if (IERC20(game.token).balanceOf(msg.sender) < game.entryPrice) {
            revert InsufficientBalance();
        }

        IERC20(game.token).transferFrom(
            msg.sender,
            address(this),
            game.entryPrice
        );
        /**
        a random is generated for the key, this key allows
        to randomnly pick a card of 25 numbers
        */
        bytes32 key = getRandomNumber();
        players[msg.sender].totalBets += game.entryPrice;
        // players[msg.sender].cardPerGame[_gameId] = new uint256[](24);
        players[msg.sender].hasJoin[_gameId] = true;
        players[msg.sender].isKeyOwner[key] = true;
        // key assign for the game
        players[msg.sender].gameKey[_gameId] = key;
        games[_gameId].gameTotalBets += game.entryPrice;

        emit Bet(
            msg.sender,
            game.entryPrice,
            _gameId
            // players[msg.sender].cardPerGame[_gameId]
        );
        return key;
    }

    /**
    @dev getCard function should be call after player paies the entry fees, a limit of time is set before calling to wait random number to be generated
    @param _gameId id of the game player has paid the fees for
    @param key, key is the randomness number generate for the user when paid the entry fees 
    */
    function getCard(uint256 _gameId, bytes32 key) external {
        if (players[msg.sender].isKeyOwner[key] != true) {
            revert EntryDenied();
        }
        if (players[msg.sender].hasJoin[_gameId] != true) {
            revert NotGameParticipant();
        }
        for (uint256 i; i < 25; i++) {
            players[msg.sender].board[_gameId][i] =
                (uint256(
                    keccak256(
                        abi.encode(players[msg.sender].gameKey[_gameId], i)
                    )
                ) % 75) +
                1;
        }
    }

    /**
    @notice get a bytes32 number link to game, it will be use as randomn
    key for sort of this game
    @param _gameId Id of the game owner generate the key  
    */
    function generateGameKey(uint256 _gameId) external onlyOwner {
        gameKey[_gameId] = getRandomNumber();
    }

    /**
    @dev generate numbers linked to value, type A -> X 
    where A represent numbers between 1-5 and X numbers between 1-75
    bingo getting 5 column, and result like position 3 -> 48 can be sort, 
    if a user has 48 in the column 3 he's able to mark
    @param _gameId ID of the game we would like to generate a result 
    */
    function generateGameResult(uint256 _gameId, uint256 _turn)
        external
        onlyOwner
    {
        require(games[_gameId].turnDuration <= _turn, "!turns");
        for (uint256 i; i < _turn; i++) {
            uint256 idx = (uint256(keccak256(abi.encode(gameKey[_gameId], i))) %
                5) + 1;
            gameResult[_gameId][idx] =
                (uint256(keccak256(abi.encode(gameKey[_gameId], i))) % 75) +
                1;
        }
    }

    /**
    @dev check result allow player to verify if he wins or not
    player has a grid of 25 numbers 5x5, the check result will loop horizontaly, vertically and diagonaly
    if card[i] with 0<i<24 equal gameResult[gameIdentifiant][column], user mark a point
    user has to complete 5 points to win the game, 
    @param _gameId game player would like to verify
    */
    function checkResult(uint256 _gameId) external {
        require(players[msg.sender].hasJoin[_gameId] == true, "not player");
        for (uint256 i; i < 5; i++) {
            // loop will check vertically the grid, if match,
            // player received the total amount bet for the game
            if (
                players[msg.sender].board[_gameId][i * 5 + 0] ==
                gameResult[_gameId][1] &&
                players[msg.sender].board[_gameId][i * 5 + 1] ==
                gameResult[_gameId][2] &&
                players[msg.sender].board[_gameId][i * 5 + 2] ==
                gameResult[_gameId][3] &&
                players[msg.sender].board[_gameId][i * 5 + 3] ==
                gameResult[_gameId][4] &&
                players[msg.sender].board[_gameId][i * 5 + 4] ==
                gameResult[_gameId][5]
            ) {
                IERC20(games[_gameId].token).transfer(
                    msg.sender,
                    games[_gameId].entryPrice
                );
            }
            // loop check horizontal matches, descending from line 1
            if (
                players[msg.sender].board[_gameId][0 + i] ==
                gameResult[_gameId][1] &&
                players[msg.sender].board[_gameId][5 + i] ==
                gameResult[_gameId][2] &&
                players[msg.sender].board[_gameId][10 + i] ==
                gameResult[_gameId][3] &&
                players[msg.sender].board[_gameId][15 + i] ==
                gameResult[_gameId][4] &&
                players[msg.sender].board[_gameId][20 + i] ==
                gameResult[_gameId][5]
            ) {
                IERC20(games[_gameId].token).transfer(
                    msg.sender,
                    games[_gameId].entryPrice
                );
            }
        }
        // check diagonally starting from the left
        if (
            players[msg.sender].board[_gameId][0] == gameResult[_gameId][1] &&
            players[msg.sender].board[_gameId][6] == gameResult[_gameId][2] &&
            players[msg.sender].board[_gameId][12] == gameResult[_gameId][3] &&
            players[msg.sender].board[_gameId][18] == gameResult[_gameId][4] &&
            players[msg.sender].board[_gameId][24] == gameResult[_gameId][5]
        ) {
            IERC20(games[_gameId].token).transfer(
                msg.sender,
                games[_gameId].entryPrice
            );
        }
        // check diagonally starting from the right
        if (
            players[msg.sender].board[_gameId][4] == gameResult[_gameId][5] &&
            players[msg.sender].board[_gameId][8] == gameResult[_gameId][4] &&
            players[msg.sender].board[_gameId][12] == gameResult[_gameId][3] &&
            players[msg.sender].board[_gameId][16] == gameResult[_gameId][2] &&
            players[msg.sender].board[_gameId][20] == gameResult[_gameId][1]
        ) {
            IERC20(games[_gameId].token).transfer(
                msg.sender,
                games[_gameId].entryPrice
            );
        }
    }

    /**
    @dev retrieve the Data from game
    @param _gameId game Id
    @return Game memory
    */
    function getGameDetails(uint256 _gameId) public view returns (Game memory) {
        return games[_gameId];
    }

    function getPlayerCard(address _address, uint256 _gameId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory card = new uint256[](25);
        for (uint256 i; i < card.length; i++) {
            card[i] = players[_address].board[_gameId][i];
        }
        return card;
    }

    /**
    @dev function returns number of all game bingo smart contract has hosted 
    */
    function getGameCount() public view returns (uint256) {
        return nextGameId;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() internal returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function getNumber() public view returns (uint256) {
        return randomResult;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;
    }
}
