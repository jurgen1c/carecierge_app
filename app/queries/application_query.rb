class ApplicationQuery
  class << self
    def resolve(...) = new.resolve(...)
    alias_method :call, :resolve

    def query_model
      name.sub(/::[^:]+$/, "").safe_constantize
    end
  end

  private attr_reader :relation

  def initialize(relation = self.class.query_model&.all)
    @relation = relation
  end

  def resolve(...)
    relation
  end
end
