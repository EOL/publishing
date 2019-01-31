module UsersHelper
  def user_form(options, &block)
    class_names = ["eol-userform", "uk-form-stacked"]
    class_names << "recaptchad" if options[:recaptchad]

    simple_form_for(
      options[:resource], 
      url: options[:url], 
      method: options[:method] || :post,
      validate: true,
      html: { class: class_names.join(" ") },
      defaults: { 
        input_html: { class: "uk-input" },
        wrapper_html: { class: "field" },
        label_html: { class: "uk-form-label" }
      }, &block)
  end
end
