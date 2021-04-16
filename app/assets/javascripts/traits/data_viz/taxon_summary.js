window.TaxonSummaryViz = (function(exports) {
  const width = 800
      , height = 500
      , pad = 3
      , bgColor = 'rgb(163, 245, 207)'
      , outerCircColor = 'rgb(81, 183, 196)'
      , innerCircColor = '#fff'
      ;

  function build($contain) {
    const $viz = $contain.find('.js-taxon-summary')
        , data = $viz.data('json')
        , root = pack(data)
        ;

    const svg = d3.select($viz[0])
      .append('svg')
      .attr('width', width)
      .style('width', width)
      .attr('height', height)
      .style('height', height)
      .style('margin', '0 auto')
      .style('display', 'block')
      .style('background', bgColor)
      ;

    const node = svg.append('g')
      .selectAll('circle')
      .data(root.descendants().slice(1))
      .join('circle')
        .attr('fill', d => d.children ? outerCircColor : innerCircColor)
        .attr('cx', d => d.x)
        .attr('cy', d => d.y)
        .attr('r', d => d.r)
        ;

    const label = svg.append('g')
      .style('font',  '10px sans-serif')
      .attr('text-anchor', 'middle')
      .selectAll('text')
      .data(root.descendants().slice(1))
      .join('text')
        .style('fill-opacity', d => d.children ? 1 : 0)
        .style('display', d => d.children ? 'inline' : 'none')
        .text(d => d.data.name)
        .attr('x', d => d.x)
        .attr('y', d => d.y)
      ;

    console.log(root);
  }
  exports.build = build;

  function pack(data) {
    return d3.pack()
        .size([width, height])
        .padding(pad)
      (d3.hierarchy(data)
        .sum(d => d.count)
        .sort((a, b) => b.count - a.count))
  }

  return exports;
})({});
