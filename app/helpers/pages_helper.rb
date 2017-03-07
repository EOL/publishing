module PagesHelper
  def classification(this_node, ancestors)
    ancestors = Array(ancestors)
    return nil if ancestors.empty?
    node = ancestors.shift
    page = this_node.nil? ? @page : node.page
    vernacular = page.name if page
    names = vernacular && vernacular != node.canonical_form ? "#{vernacular} (#{node.canonical_form})" : node.canonical_form

    # <article class="uk-comment">
    #     <header class="uk-comment-header uk-grid-medium uk-flex-middle" uk-grid>
    #         <div class="uk-width-auto">
    #             <img class="uk-comment-avatar" src="../docs/images/avatar.jpg" width="80" height="80" alt="">
    #         </div>
    #         <div class="uk-width-expand">
    #             <h4 class="uk-comment-title uk-margin-remove"><a class="uk-link-reset" href="#">Author</a></h4>
    #             <ul class="uk-comment-meta uk-subnav uk-subnav-divider uk-margin-remove-top">
    #                 <li><a href="#">12 days ago</a></li>
    #                 <li><a href="#">Reply</a></li>
    #             </ul>
    #         </div>
    #     </header>
    #     <div class="uk-comment-body">
    #         <p>Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.</p>
    #     </div>
    # </article>


    haml_tag("li") do
      haml_tag("div.uk-grid-collapse.uk-flex-middle", uk: {grid: true}) do
        haml_tag("div.uk-width-auto") do
          if page && page.icon
            haml_concat image_tag(page.icon, size: "40x40", class: "uk-margin-right")
          end
        end
        haml_tag("div.uk-width-expand") do
          haml_tag("h5.uk-header.uk-margin-remove") do
            if this_node
              haml_concat link_to(names.html_safe, node.page_id ? page_path(node.page_id) : "#")
            else
              haml_concat names.html_safe
              haml_concat t(:classification_list_this_page)
            end
            haml_tag("ul.uk-subnav.uk-subnav-divider.uk-margin-remove-top.uk-padding-remove-horizontal") do
              if page
                haml_tag("li.uk-padding-remove-horizontal") do
                  haml_concat "<span uk-icon='icon: image'></span>&ensp;<span class='uk-badge'>#{page.media_count}</span>".html_safe
                end
                haml_tag("li") do
                  haml_concat "<span uk-icon='icon: tag'></span>&ensp;<span class='uk-badge'>#{page.traits.size}</span>".html_safe
                end
                haml_tag("li") do
                  haml_concat "<span uk-icon='icon: social'></span>&ensp;<span class='uk-badge'>#{page.nodes.size}</span>".html_safe
                end
                haml_tag("li.uk-text-muted") do
                  haml_concat "etc..."
                end
              else
                haml_tag("li.uk-padding-remove-horizontal.uk-text-muted") do
                  haml_concat "PAGE MISSING (bad import)" # TODO: something more elegant.
                end
              end
            end
          end
        end
      end
      if ancestors.empty? && this_node
        haml_tag("ul.uk-list") do
          classification(nil, [this_node])
        end
      else
        haml_tag("ul.uk-list") do
          classification(this_node, ancestors)
        end
      end
    end
  end
end
