// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DeveloperExpressionRegistry is AccessControl, ERC721URIStorage {
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    struct ExpressionMetadata {
        bytes32 engineType;
        bytes32 expressionHash;
        address originalMinter;
        bool active;
    }

    uint256 public nextExpressionId = 1;

    mapping(uint256 => ExpressionMetadata) private expressions;

    event ExpressionMinted(
        uint256 indexed expressionTokenId,
        bytes32 indexed engineType,
        address indexed developer,
        bytes32 expressionHash,
        string metadataURI
    );
    event ExpressionActiveSet(uint256 indexed expressionTokenId, bool active);

    constructor(address admin) ERC721("Scuro Developer Expression", "SCUDEV") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MODERATOR_ROLE, admin);
    }

    function mintExpression(bytes32 engineType, bytes32 expressionHash, string calldata metadataURI)
        external
        returns (uint256 expressionTokenId)
    {
        require(engineType != bytes32(0), "ExpressionRegistry: zero type");
        require(expressionHash != bytes32(0), "ExpressionRegistry: zero hash");
        require(bytes(metadataURI).length > 0, "ExpressionRegistry: empty uri");

        expressionTokenId = nextExpressionId++;
        expressions[expressionTokenId] = ExpressionMetadata({
            engineType: engineType,
            expressionHash: expressionHash,
            originalMinter: msg.sender,
            active: true
        });
        _safeMint(msg.sender, expressionTokenId);
        _setTokenURI(expressionTokenId, metadataURI);

        emit ExpressionMinted(expressionTokenId, engineType, msg.sender, expressionHash, metadataURI);
    }

    function setExpressionActive(uint256 expressionTokenId, bool active) external onlyRole(MODERATOR_ROLE) {
        _requireExpression(expressionTokenId);
        expressions[expressionTokenId].active = active;
        emit ExpressionActiveSet(expressionTokenId, active);
    }

    function getExpressionMetadata(uint256 expressionTokenId) external view returns (ExpressionMetadata memory) {
        _requireExpression(expressionTokenId);
        return expressions[expressionTokenId];
    }

    function isExpressionCompatible(bytes32 engineType, uint256 expressionTokenId) external view returns (bool) {
        _requireExpression(expressionTokenId);
        ExpressionMetadata memory metadata = expressions[expressionTokenId];
        return metadata.active && metadata.engineType == engineType;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _requireExpression(uint256 expressionTokenId) internal view {
        require(_ownerOf(expressionTokenId) != address(0), "ExpressionRegistry: unknown");
    }
}
