// copied from/based on https://observablehq.com/@d3/parallel-sets"
window.Sankey = (function(exports) {
  exports.build = function() {
    const width = 850
        , height = 520
        ;

    $data = $('.js-sankey')
    const graph = {
      nodes: $data.data('nodes'),
      links: $data.data('links')
    }

    const sankey = d3.sankey()
      .nodeSort(null)
      .linkSort(null)
      .nodeWidth(4)
      .nodePadding(25)
      .extent([[0, 5], [width, height - 20]])
      .nodeId((d) => d.uri);

    const svg = d3.select(".js-sankey")
      .append("svg")
      .attr("width", width)
      .style("width", width)
      .attr("height", height)
      .style("height", height)
      .style("margin", "0 auto")
      .style("display", "block");

    const {nodes, links} = sankey({
      nodes: graph.nodes.map(d => Object.assign({}, d)),
      links: graph.links.map(d => Object.assign({}, d))
    });

    svg.append("g")
      .selectAll("rect")
      .data(nodes)
      .join("rect")
        .attr("x", d => d.x0)
        .attr("y", d => d.y0)
        .attr("height", d => d.y1 - d.y0)
        .attr("width", d => d.x1 - d.x0)
      .append("title")
        .text(d => `${d.name}\n${d.value.toLocaleString()}`);


    var link = d3.linkHorizontal()
      .source((d) => [d.source.x1, Math.min(d.source.y1 - (d.width / 2.0), d.y0)])
      .target((d) => [d.target.x0, Math.min(d.target.y1 - (d.width / 2.0), d.y1)]);

    svg.append("g")
        .attr("fill", "none")
      .selectAll("g")
      .data(links)
      .join("path")
        .attr("d", link)
        .attr("stroke", d => "#89c783")
        .attr("stroke-width", d => d.width)
        .style("mix-blend-mode", "multiply")
      .append("title")
        .text(d => `${d.names.join(" → ")}\n${d.value.toLocaleString()}`);

    svg.append("g")
        .style("font", "10px sans-serif")
      .selectAll("text")
      .data(nodes)
      .join("text")
        .attr("x", d => d.x0 < width / 2 ? d.x1 : d.x0)
        .attr("y", d => d.y1 + 10)
        .attr("dy", "0.35em")
        .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
        .text(d => d.name)
      .append("tspan")
        .attr("fill-opacity", 0.7)
        .text(d => ` ${d.value.toLocaleString()}`);

    svg.node();
  }

  return exports;
})({});
