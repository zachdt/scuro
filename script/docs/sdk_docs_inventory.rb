module SdkDocsInventory
  module_function

  def entries
    @entries ||= [
      ["ProtocolSettlement", "src/ProtocolSettlement.sol", "docs/reference/protocol-settlement.md", "core"],
      ["GameCatalog", "src/GameCatalog.sol", "docs/reference/game-catalog.md", "core"],
      ["GameDeploymentFactory", "src/GameDeploymentFactory.sol", "docs/reference/game-deployment-factory.md", "core"],
      ["DeveloperExpressionRegistry", "src/DeveloperExpressionRegistry.sol", "docs/reference/developer-expression-registry.md", "economics"],
      ["DeveloperRewards", "src/DeveloperRewards.sol", "docs/reference/developer-rewards.md", "economics"],
      ["ScuroToken", "src/ScuroToken.sol", "docs/reference/scuro-token.md", "economics"],
      ["ScuroStakingToken", "src/ScuroStakingToken.sol", "docs/reference/scuro-staking-token.md", "economics"],
      ["ScuroGovernor", "src/ScuroGovernor.sol", "docs/reference/scuro-governor.md", "governance"],
      ["NumberPickerAdapter", "src/controllers/NumberPickerAdapter.sol", "docs/reference/number-picker-adapter.md", "controller"],
      ["TournamentController", "src/controllers/TournamentController.sol", "docs/reference/tournament-controller.md", "controller"],
      ["PvPController", "src/controllers/PvPController.sol", "docs/reference/pvp-controller.md", "controller"],
      ["BlackjackController", "src/controllers/BlackjackController.sol", "docs/reference/blackjack-controller.md", "controller"],
      ["NumberPickerEngine", "src/engines/NumberPickerEngine.sol", "docs/reference/number-picker-engine.md", "engine"],
      ["SingleDeckBlackjackEngine", "src/engines/SingleDeckBlackjackEngine.sol", "docs/reference/single-deck-blackjack-engine.md", "engine"],
      ["SingleDraw2To7Engine", "src/engines/SingleDraw2To7Engine.sol", "docs/reference/single-draw-2-7-engine.md", "engine"],
      ["PokerVerifierBundle", "src/verifiers/PokerVerifierBundle.sol", "docs/reference/poker-verifier-bundle.md", "verifier"],
      ["BlackjackVerifierBundle", "src/verifiers/BlackjackVerifierBundle.sol", "docs/reference/blackjack-verifier-bundle.md", "verifier"],
      ["IScuroGameEngine", "src/interfaces/IScuroGameEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["ISoloLifecycleEngine", "src/interfaces/ISoloLifecycleEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["ITournamentGameEngine", "src/interfaces/ITournamentGameEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["IPokerEngine", "src/interfaces/IPokerEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["IPokerZKEngine", "src/interfaces/IPokerZKEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["IPokerVerifierBundle", "src/interfaces/IPokerVerifierBundle.sol", "docs/reference/proof-interfaces.md", "interface"],
      ["IBlackjackVerifierBundle", "src/interfaces/IBlackjackVerifierBundle.sol", "docs/reference/proof-interfaces.md", "interface"]
    ].map do |name, source, doc, category|
      { name: name, source: source, doc: doc, category: category }
    end
  end

  def enum_labels
    {
      "GameCatalog.GameMode" => { "0" => "Solo", "1" => "PvP", "2" => "Tournament" },
      "GameCatalog.ModuleStatus" => { "0" => "LIVE", "1" => "RETIRED", "2" => "DISABLED" },
      "SingleDeckBlackjackEngine.SessionPhase" => {
        "0" => "Inactive",
        "1" => "AwaitingInitialDeal",
        "2" => "AwaitingPlayerAction",
        "3" => "AwaitingCoordinator",
        "4" => "Completed"
      },
      "SingleDeckBlackjackEngine.Action" => {
        "1" => "ACTION_HIT",
        "2" => "ACTION_STAND",
        "3" => "ACTION_DOUBLE",
        "4" => "ACTION_SPLIT"
      },
      "SingleDeckBlackjackEngine.ActionMask" => {
        "1" => "ALLOW_HIT",
        "2" => "ALLOW_STAND",
        "4" => "ALLOW_DOUBLE",
        "8" => "ALLOW_SPLIT"
      },
      "SingleDraw2To7Engine.MatchState" => { "0" => "Inactive", "1" => "Active", "2" => "Completed" },
      "SingleDraw2To7Engine.HandPhase" => {
        "0" => "None",
        "1" => "AwaitingInitialDeal",
        "2" => "PreDrawBetting",
        "3" => "DrawDeclaration",
        "4" => "DrawProofPending",
        "5" => "PostDrawBetting",
        "6" => "ShowdownProofPending",
        "7" => "HandComplete"
      }
    }
  end

  def proof_inputs
    {
      "IPokerVerifierBundle.InitialDealPublicInputs" => %w[
        gameId handNumber handNonce deckCommitment handCommitments encryptionKeyCommitments ciphertextRefs
      ],
      "IPokerVerifierBundle.DrawPublicInputs" => %w[
        gameId handNumber handNonce playerIndex deckCommitment oldCommitment newCommitment
        newEncryptionKeyCommitment newCiphertextRef discardMask proofSequence
      ],
      "IPokerVerifierBundle.ShowdownPublicInputs" => %w[
        gameId handNumber handNonce handCommitments winnerIndex isTie
      ],
      "IBlackjackVerifierBundle.InitialDealPublicInputs" => %w[
        sessionId handNonce deckCommitment playerStateCommitment dealerStateCommitment playerKeyCommitment
        playerCiphertextRef dealerCiphertextRef dealerUpValue handCount activeHandIndex payout
        immediateResultCode handValues softMask handStatuses allowedActionMasks
      ],
      "IBlackjackVerifierBundle.ActionPublicInputs" => %w[
        sessionId proofSequence pendingAction oldPlayerStateCommitment newPlayerStateCommitment
        dealerStateCommitment playerKeyCommitment playerCiphertextRef dealerCiphertextRef dealerUpValue
        handCount activeHandIndex nextPhase handValues softMask handStatuses allowedActionMasks
      ],
      "IBlackjackVerifierBundle.ShowdownPublicInputs" => %w[
        sessionId proofSequence playerStateCommitment dealerStateCommitment payout dealerFinalValue
        handCount activeHandIndex handStatuses
      ]
    }
  end

  def local_defaults
    {
      "number_picker" => {
        "config_hash_label" => "number-picker-auto",
        "developer_reward_bps" => 500,
        "vrf_mode" => "auto-callback mock"
      },
      "tournament_poker" => {
        "config_hash_label" => "single-draw-2-7-tournament",
        "small_blind" => 10,
        "big_blind" => 20,
        "blind_escalation_interval" => 180,
        "action_window" => 60,
        "developer_reward_bps" => 1000
      },
      "pvp_poker" => {
        "config_hash_label" => "single-draw-2-7-pvp",
        "small_blind" => 10,
        "big_blind" => 20,
        "blind_escalation_interval" => 180,
        "action_window" => 60,
        "developer_reward_bps" => 1000
      },
      "blackjack" => {
        "config_hash_label" => "single-deck-blackjack-zk",
        "default_action_window" => 60,
        "developer_reward_bps" => 500
      }
    }
  end

  def deployment_output_labels
    {
      "core" => %w[
        ScuroToken ScuroStakingToken TimelockController ScuroGovernor GameCatalog GameDeploymentFactory
        DeveloperExpressionRegistry DeveloperRewards ProtocolSettlement
      ],
      "controllers" => %w[NumberPickerAdapter TournamentController PvPController BlackjackController],
      "engines" => %w[NumberPickerEngine TournamentPokerEngine PvPPokerEngine SingleDeckBlackjackEngine],
      "verifiers" => %w[TournamentPokerVerifierBundle PvPPokerVerifierBundle BlackjackVerifierBundle],
      "module_ids" => %w[NumberPickerModuleId TournamentPokerModuleId PvPPokerModuleId BlackjackModuleId],
      "actors" => %w[Admin Player1 Player2 SoloDeveloper PokerDeveloper],
      "expressions" => %w[NumberPickerExpressionTokenId PokerExpressionTokenId BlackjackExpressionTokenId]
    }
  end
end
