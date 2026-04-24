module SdkDocsInventory
  module_function
  ROOT = File.expand_path("../..", __dir__)

  def entries
    @entries ||= [
      ["ProtocolSettlement", "src/ProtocolSettlement.sol", "docs/reference/protocol-settlement.md", "core"],
      ["GameCatalog", "src/GameCatalog.sol", "docs/reference/game-catalog.md", "core"],
      ["DeveloperExpressionRegistry", "src/DeveloperExpressionRegistry.sol", "docs/reference/developer-expression-registry.md", "economics"],
      ["DeveloperRewards", "src/DeveloperRewards.sol", "docs/reference/developer-rewards.md", "economics"],
      ["ScuroToken", "src/ScuroToken.sol", "docs/reference/scuro-token.md", "economics"],
      ["ScuroStakingToken", "src/ScuroStakingToken.sol", "docs/reference/scuro-staking-token.md", "economics"],
      ["ScuroGovernor", "src/ScuroGovernor.sol", "docs/reference/scuro-governor.md", "governance"],
      ["NumberPickerAdapter", "src/controllers/NumberPickerAdapter.sol", "docs/reference/number-picker-adapter.md", "controller"],
      ["SlotMachineController", "src/controllers/SlotMachineController.sol", "docs/reference/slot-machine-controller.md", "controller"],
      ["NumberPickerEngine", "src/engines/NumberPickerEngine.sol", "docs/reference/number-picker-engine.md", "engine"],
      ["SlotMachineEngine", "src/engines/SlotMachineEngine.sol", "docs/reference/slot-machine-engine.md", "engine"],
      ["IScuroGameEngine", "src/interfaces/IScuroGameEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"],
      ["ISoloLifecycleEngine", "src/interfaces/ISoloLifecycleEngine.sol", "docs/reference/gameplay-interfaces.md", "interface"]
    ].map do |name, source, doc, category|
      { name: name, source: source, doc: doc, category: category }
    end
  end

  def enum_labels
    {
      "GameCatalog.ModuleStatus" => { "0" => "LIVE", "1" => "RETIRED", "2" => "DISABLED" },
      "SlotMachineEngine.VolatilityTier" => {
        "1" => "VOL_LOW",
        "2" => "VOL_MEDIUM",
        "3" => "VOL_HIGH",
        "4" => "VOL_EXTREME"
      },
      "SlotMachineEngine.SpinStatus" => {
        "1" => "STATUS_PENDING",
        "2" => "STATUS_RESOLVED"
      }
    }
  end

  def local_defaults
    {
      "number_picker" => {
        "config_hash_label" => "number-picker-auto",
        "developer_reward_bps" => 500,
        "vrf_mode" => "auto-callback mock"
      },
      "slot_machine" => {
        "config_hash_label" => "slot-machine-auto",
        "presets" => %w[base free pick hold],
        "developer_reward_bps" => 500
      }
    }
  end

  def deployment_output_labels
    {
      "core" => %w[
        ScuroToken ScuroStakingToken TimelockController ScuroGovernor GameCatalog
        DeveloperExpressionRegistry DeveloperRewards ProtocolSettlement
      ],
      "controllers" => %w[NumberPickerAdapter SlotMachineController],
      "engines" => %w[NumberPickerEngine SlotMachineEngine],
      "module_ids" => %w[NumberPickerModuleId SlotMachineModuleId],
      "slot_presets" => %w[SlotBasePresetId SlotFreePresetId SlotPickPresetId SlotHoldPresetId],
      "actors" => %w[Admin Player1 Player2 SoloDeveloper],
      "expressions" => %w[NumberPickerExpressionTokenId SlotMachineExpressionTokenId]
    }
  end
end
