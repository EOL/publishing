module SearchHelper
  def result_total(results)
    total = 0
    results.compact.each do |r|
      # TODO: this rescue is sloppy, but I was getting cases where the delegated array was nil and there was NO way to
      # test that from "out here." We're not *overly* concerned about errors here...
      total += r.total_count rescue 0
    end
    total
  end

  def any_results(results)
    count = results&.total_count rescue 0
    results && count > 0
  end

  def first_type_with_results(results)
    first_type = results.find { |result| any_results(result) }
    return nil if first_type.nil?
    first_instance = first_type.first
    type =
      if first_instance.class.name =~ /SearchDecorator/
        first_instance.class.name.sub('SearchDecorator', '').downcase
      else
        if first_instance.class == Medium
          first_instance.subclass
        else
          first_instance.class.name.downcase
        end
      end
    type.pluralize.to_sym
  end
end
