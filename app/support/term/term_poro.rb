class TermPoro
  delegate :query, to: TraitBank

  def initialize(uri)
    @uri = uri
    instance = TraitBank.term(uri)
    raise "Missing term." if instance.nil?
    @instance = instance["data"]
  end

  def predicate_uses
    query(%{MATCH (trait:Trait)-[:predicate]->(:Term { uri: '#{@uri}'}) RETURN COUNT(trait)})["data"].first.first
  end

  def object_uses
    query(%{MATCH (trait:Trait)-[:object_term]->(:Term { uri: '#{@uri}'}) RETURN COUNT(trait)})["data"].first.first
  end

  def synonyms
    query(%{MATCH (term:Term { uri: "#{@uri}" })-[:synonym_of]->(rel:Term) RETURN rel.uri})["data"].first
  end

  def parents
    query(%{MATCH (term:Term { uri: "#{@uri}" })-[:parent_term]->(rel:Term) RETURN rel.uri})["data"].first
  end

  def synonyms_of
    query(%{MATCH (term:Term { uri: "#{@uri}" })<-[:synonym_of]-(rel:Term) RETURN rel.uri})["data"].first
  end

  def children
    query(%{MATCH (term:Term { uri: "#{@uri}" })<-[:parent_term]-(rel:Term) RETURN rel.uri})["data"].first
  end

  def relationships
    puts "Parents: #{expalin_rel(parents)}"
    puts "Children: #{expalin_rel(children)}"
    puts "Synonyms: #{expalin_rel(synonyms)}"
    puts "Synonyms Of: #{expalin_rel(synonyms_of)}"
    puts "Used as a predicate #{predicate_uses} times."
    puts "Used as an object #{object_uses} times."
  end

  def expalin_rel(rel)
    explanation = rel.nil? ? 'none.' : rel.join(', ')
  end

  # NOTE this is a copy of an old method from TraitBank::Terms, but **I want this copied**, not to use that method.
  def uses_object_terms_directly?
    query(
      %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term { uri: '#{@uri}'}) RETURN term.uri LIMIT 1}
    )["data"]
  end

  def incoming_relatives_use_object_terms?
    query(
      %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*]->(:Term { uri: '#{@uri}'}) RETURN term.uri LIMIT 1}
    )["data"]
  end

  # NOTE: this is pr-r-r-r-r-r-robably the same as TraitBank::Terms.any_obj_terms_for_pred? ...but that may change and
  # we want this stable
  def outgoing_relatives_use_object_terms?
    query(
      %{MATCH (term:Term)<-[:object_term]-(:Trait)-[:predicate]->(:Term)<-[:synonym_of|:parent_term*]-(:Term { uri: '#{@uri}'}) RETURN term.uri LIMIT 1}
    )["data"]
  end

  def relatives_of_relatives_use_object_terms?
    # One of the terms that this points to is itself pointed to by a term that is actually used.
    query(%{MATCH (term:Term)<-[:object_term]-(trait:Trait)-[:predicate]->(:Term)-[:synonym_of|:parent_term*]->(:Term)<-[:synonym_of|:parent_term*]-(:Term { uri: '#{@uri}'}) RETURN term.uri LIMIT 1})["data"]
  end
end
