require "rails_helper"

RSpec.describe "On-demand concierge capabilities" do
  let(:chat) { double("RubyLLM chat", with_tools: nil) }
  let(:tool) { Concierge::CapabilitiesTool.new(chat:, turn: nil, token: nil) }

  it "makes every fixed capability discoverable without loading every argument schema" do
    names = Concierge::Catalog.all.map { |operation| operation.name.split(".").first }.uniq

    expect(tool.params_schema.dig(:properties, :capabilities, :items, :enum)).to match_array(names)
    expect(tool.description).to include("plans", "briefings", "reminders", "quotes")
  end

  it "loads requested capabilities alongside people, memories, and the capability selector" do
    result = tool.call("capabilities" => %w[plans reminders])

    expect(result).to include("status" => "ready")
    expect(chat).to have_received(:with_tools) do |*tools, **options|
      expect(result.fetch("enabled_tools")).to match_array(tools.map(&:name))
      expect(tools.map(&:name)).to include("people_search", "memories_create", "plans_create", "reminders_create", "capabilities")
      expect(tools.map(&:name)).not_to include("quotes_create")
      expect(tools.find { |entry| entry.name == "plans_create" }.params_schema).to include(required: include("title"))
      expect(options).to include(replace: true, concurrency: false)
    end
  end

  it "rejects arbitrary or excessive capability requests before changing available tools" do
    [ { "capabilities" => [ "Kernel" ] }, { "capabilities" => %w[plans dates reminders] },
      { "capabilities" => "plans" }, { "capabilities" => [ "plans" ], "user_id" => SecureRandom.uuid } ].each do |arguments|
      expect(tool.call(arguments)).to include("status" => "invalid_arguments")
    end
    expect(chat).not_to have_received(:with_tools)
  end
end
