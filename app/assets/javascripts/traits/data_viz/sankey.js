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
    , numAxes = $data.data('axes')
    ;

    const sankey = d3.sankey()
      .nodeSort(null)
      .linkSort(null)
      .nodeWidth(15)
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
      .style("display", "block")

    const {nodes, links} = sankey({
      nodes: graph.nodes.map(d => Object.assign({}, d)),
      links: graph.links.map(d => Object.assign({}, d))
    });

    const link = d3.linkHorizontal()
      .source((d) => [d.source.x1, Math.min(d.source.y1 - (d.width / 2.0), d.y0)])
      .target((d) => [d.target.x0, Math.min(d.target.y1 - (d.width / 2.0), d.y1)]);

    var selectedNodes = {};

    const nodeG = svg.append("g");
    updateNodes();

    const linkG = svg.append("g")
        .attr("fill", "none");

    updateLinks();

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

    function handleNodeClick(e, d) {
      window.location = d.searchPath;
      /*
      setSelectedNode(d);
      updateSelectedLinks();
      sortLinks();
      updateLinks();
      updateNodes();
      */
    }

    function setSelectedNode(node) {
      if (selectedNodes[node.axisId] == node) {
        // unset
        selectedNodes[node.axisId] = null;
      } else {
        //set
        selectedNodes[node.axisId] = node;
      }
    }

    function sortLinks() {
      links.sort((a, b) => {
        if (a.selected && !b.selected) {
          return 1;
        } else if (!a.selected && b.selected) {
          return -1; 
        } else {
          return 0;
        }
      });

    }

    function updateSelectedLinks() {
      links.forEach((l) => {
        let selected = true;

        for (let i = 0; selected && i < numAxes - 1; i++) {
          let isLinkIndex = !l.connections[i]
            , sourceIndex = i
            , targetIndex = i + 1
            ;

          if (isLinkIndex) {
            selected = (!selectedNodes[sourceIndex] || selectedNodes[sourceIndex].uri == l.source.uri) &&
              (!selectedNodes[targetIndex] || selectedNodes[targetIndex].uri == l.target.uri);
          } else {
            selected = !!(l.connections[i].find((c) => {
              return (!selectedNodes[sourceIndex] || c.source_uri == selectedNodes[sourceIndex].uri) &&
              (targetMatch = !selectedNodes[targetIndex] || c.target_uri == selectedNodes[targetIndex].uri)
            }));
          }
        }

        l.selected = selected;
      });
      console.log(links);
    }

    function setSelectedLink(selectedLink) {
      links.forEach((l) => {
        const selected = (
          l == selectedLink ||
          selectedLink.connections.find((c) => l.source.uri == c.source_uri && l.target.uri == c.target_uri)
        );

        l.selected = selected;
      })

      updateLinks();
    }

    function unsetSelectedLink() {
      links.forEach((l) => {
        l.selected = true;
      });

      updateLinks();
    }

    function linkColor(d) {
      if (d.selected) {
        return "#89c783";
      } else {
        return "#eee";
      }
    }

    function colorPaths() {
      svg.selectAll('path')
        .attr('stroke', linkColor)
    }

    function updateLinks() {
      linkG.selectAll('path')
       .data(links)
       .join("path")
         .attr("d", link)
         .attr("stroke", linkColor)
         .attr("stroke-width", d => d.width)
       .append("title")
         .text(d => `${d.names.join(" → ")}\n${d.value.toLocaleString()}`)
       .order();
    }

    function updateNodes() {
      nodeG.selectAll("rect")
        .data(nodes)
        .join("rect")
          .attr("x", d => d.x0)
          .attr("y", d => d.y0)
          .attr("height", d => d.y1 - d.y0)
          .attr("width", d => d.x1 - d.x0)
          .attr('fill', nodeFillColor)
          .attr('stroke', nodeStrokeColor)
          .attr('stroke-width', nodeStrokeWidth)
          .style('cursor', 'pointer')
          .on('click', handleNodeClick)
        .append("title")
          .text(d => `${d.name}\n${d.value.toLocaleString()}`);
    }

    function nodeFillColor(d) {
      return !selectedNodes[d.axisId] || selectedNodes[d.axisId] == d ? '#000' : '#aaa'
    }

    function nodeStrokeColor(d) {
      return selectedNodes[d.axisId] == d ? "#3aF" : null;
    }

    function nodeStrokeWidth(d) {
      return selectedNodes[d.axisId] == d ? 3 : 0;
    }
  }
  return exports;
})({});
