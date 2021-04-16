window.TaxonSummaryViz = (function(exports) {
  const width = 600
      , height = 500
      , pad = 3
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
      .style('display', 'block');

    const node = svg.append('g')
      .selectAll('circle')
      .data(root.descendants().slice(1))
      .join('circle')
        .attr('fill', d => d.children ? 'blue' : 'gray')
        .attr('cx', d => d.x)
        .attr('cy', d => d.y)
        .attr('r', d => d.r);
     

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
