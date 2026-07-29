require "test_helper"

class TraitBankCorruptionTest < ActiveSupport::TestCase
  setup do
    @page_id = 9_999_001
    TraitBank::Corruption.clear_page!(@page_id)
  end

  teardown do
    TraitBank::Corruption.clear_page!(@page_id)
  end

  test "chain_corruption? detects NOT PART OF CHAIN message" do
    error = StandardError.new("NOT PART OF CHAIN! RelationshipTraversalCursor[id=1]")
    assert TraitBank::Corruption.chain_corruption?(error)
  end

  test "chain_corruption? ignores unrelated errors" do
    refute TraitBank::Corruption.chain_corruption?(StandardError.new("Something else went wrong"))
  end

  test "flag_page! causes skip_page? until cleared" do
    refute TraitBank::Corruption.skip_page?(@page_id)
    TraitBank::Corruption.flag_page!(@page_id, error: StandardError.new("NOT PART OF CHAIN!"))
    assert TraitBank::Corruption.skip_page?(@page_id)
    TraitBank::Corruption.clear_page!(@page_id)
    refute TraitBank::Corruption.skip_page?(@page_id)
  end

  test "guard returns fallback and flags on chain corruption" do
    result = TraitBank::Corruption.guard(@page_id, fallback: :soft) do
      raise StandardError, "NOT PART OF CHAIN! boom"
    end

    assert_equal :soft, result
    assert TraitBank::Corruption.skip_page?(@page_id)
  end

  test "guard skips yield when page already flagged" do
    TraitBank::Corruption.flag_page!(@page_id)
    called = false
    result = TraitBank::Corruption.guard(@page_id, fallback: :soft) do
      called = true
      :ran
    end

    refute called
    assert_equal :soft, result
  end

  test "guard re-raises unrelated errors" do
    assert_raises(RuntimeError) do
      TraitBank::Corruption.guard(@page_id, fallback: :soft) { raise "nope" }
    end
    refute TraitBank::Corruption.skip_page?(@page_id)
  end

  test "extract_page_id from query and params" do
    assert_equal 42, TraitBank::Corruption.extract_page_id("MATCH (:Page { page_id: 42 })", {})
    assert_equal 7, TraitBank::Corruption.extract_page_id("MATCH (p)", page_id: 7)
  end
end
