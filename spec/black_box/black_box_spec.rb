require "rails_helper"

RSpec.describe BlackBox, type: :black_box do
  let!(:function_caller) { double }

  describe "#article_hotness_score" do
    let!(:article) { build_stubbed(:article, published_at: Time.current) }

    it "calls function caller if AWS_SDK_KEY present" do
      ENV["AWS_SDK_KEY"] = "valid_key"
      allow(function_caller).to receive(:call).and_return(5)
      described_class.article_hotness_score(article, function_caller)
      expect(function_caller).to have_received(:call).once
      ENV["AWS_SDK_KEY"] = nil
    end

    it "does not call function caller if AWS_SDK_KEY is placeholder" do
      ENV["AWS_SDK_KEY"] = "foobarbaz"
      allow(function_caller).to receive(:call).and_return(5)
      described_class.article_hotness_score(article, function_caller)
      expect(function_caller).not_to have_received(:call)
      ENV["AWS_SDK_KEY"] = nil
    end

    it "doesn't fail when function caller returns nil" do
      allow(function_caller).to receive(:call).and_return(nil)
      described_class.article_hotness_score(article, function_caller)
    end

    xit "returns the correct value" do
      article = build_stubbed(:article, score: 99, published_at: Time.current)
      allow(function_caller).to receive(:call).and_return(5)
      # recent bonuses (28 + 31 + 80 + 395 + 330 + 330 = 1194)
      # + score (99)
      # + value from the function caller (5)
      score = described_class.article_hotness_score(article, function_caller)
      expect(score).to eq(657_758)
    end

    it "returns the lower correct value if article tagged with watercooler" do
      article = build_stubbed(:article, score: 99, cached_tag_list: "hello, discuss, watercooler",
                                        published_at: Time.current)
      allow(function_caller).to receive(:call).and_return(5)
      # recent bonuses (28 + 31 + 80 + 395 + 330 + 330 = 1194)
      # + score (99)
      # + value from the function caller (5)
      score = described_class.article_hotness_score(article, function_caller)
      expect(score).to be < 657_758 # lower because watercooler tag
    end
  end

  describe "#comment_quality_score" do
    it "returns the correct score" do
      comment = build_stubbed(:comment, body_markdown: "```#{'hello, world! ' * 20}```")
      reactions = double
      allow(comment).to receive(:reactions).and_return(reactions)
      allow(reactions).to receive(:sum).with(:points).and_return(22)
      # rep_points + descendants_points + bonus_points - spaminess_rating
      # rep_points - 22
      # descendants_points - 0
      # bonus_points - 2 + 1 = 3
      # spaminess_rating - 0
      # 22 + 0 + 3 - 0 = 25
      expect(described_class.comment_quality_score(comment)).to eq(25)
    end
  end

  describe "#calculate_spaminess" do
    let(:user) { build_stubbed(:user) }
    let(:comment) { build_stubbed(:comment, user: user) }

    before do
      allow(function_caller).to receive(:call).and_return(1)
    end

    it "returns 100 if there is no user" do
      story = instance_double("Comment", user: nil)
      expect(described_class.calculate_spaminess(story, function_caller)).to eq(100)
      expect(function_caller).not_to have_received(:call)
    end

    it "calls the function_caller if AWS_SDK_KEY present" do
      ENV["AWS_SDK_KEY"] = "valid_key"
      described_class.calculate_spaminess(comment, function_caller)
      expect(function_caller).to have_received(:call).with("blackbox-production-spamScore",
                                                           { story: comment, user: user }.to_json).once
      ENV["AWS_SDK_KEY"] = nil
    end

    it "does not call the function_caller if AWS_SDK_KEY is placeholder" do
      ENV["AWS_SDK_KEY"] = "foobarbaz"
      described_class.calculate_spaminess(comment, function_caller)
      expect(function_caller).not_to have_received(:call).with("blackbox-production-spamScore",
                                                               { story: comment, user: user }.to_json)
      ENV["AWS_SDK_KEY"] = nil
    end

    it "returns the function_caller spaminess if AWS_SDK_KEY present" do
      ENV["AWS_SDK_KEY"] = "valid_key"
      spaminess = described_class.calculate_spaminess(comment, function_caller)
      expect(spaminess).to eq(1)
      ENV["AWS_SDK_KEY"] = nil
    end

    it "returns the default retrun value if AWS_SDK_KEY is placeholder" do
      ENV["AWS_SDK_KEY"] = "foobarbaz"
      spaminess = described_class.calculate_spaminess(comment, function_caller)
      expect(spaminess).to eq(0)
      ENV["AWS_SDK_KEY"] = nil
    end
  end
end
