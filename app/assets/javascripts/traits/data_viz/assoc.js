// Based on https://observablehq.com/@d3/hierarchical-edge-bundling
window.AssocViz = (function(exports) {
  exports.build = function($container) {
    const radius = 350
        , width = 900;

    const data = $container.find('.js-assoc').data('json')
        , root = d3.cluster().size([2 * Math.PI, radius - 50])(d3.hierarchy(data))
              .sort((a, b) => d3.ascending(a.height, b.height) || d3.ascending(a.data.name, b.data.name))
        , nodesById = new Map(root.leaves().map(d => [d.data.pageId, d]))
        , objLinks = root.leaves().flatMap(d => d.data.objPageIds.map(o => [d, nodesById.get(o)]))
        , line = d3.lineRadial()
            .curve(d3.curveBundle.beta(0.85))
            .radius(d => d.y)
            .angle(d => d.x)
        , svg = d3.select('.js-assoc')
          .append('svg')
            .style('width', width)
            .style('height', width)
            .style('display', 'block')
            .style('margin', '0 auto')
            .attr('viewBox', [-width / 2, -width / 2, width, width]) // coordinate (0, 0) is at center of svg viewBox

    const node = svg.append('g')
        .attr('font-family', 'sans-serif')
        .attr('font-size', 14)
      .selectAll('g')
      .data(root.leaves())
      .join('g')
        .attr('transform', d => `rotate(${d.x * 180 / Math.PI - 90}) translate(${d.y},0)`)
      .append('text')
      .attr('dy', '0.31em') // why?
      .attr('x', d => d.x < Math.PI ? 6 : -6)
      .attr('text-anchor', d => d.x < Math.PI ? 'start' : 'end')
      .attr('transform', d => d.x >= Math.PI ? 'rotate(180)' : null)
      .text(d => d.data.name)
    ;

    const link = svg.append('g')
        .attr('stroke', '#ccc')
        .attr('fill', 'none')
      .selectAll('path')
      .data(objLinks)
      .join('path')
        .style('mix-blend-mode', 'multiply')
        .attr('d', ([d, o]) => line(d.path(o)))
    ;
      

  }

  return exports;
})({});

