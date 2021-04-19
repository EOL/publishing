window.TaxonSummaryViz = (function(exports) {
  const width = 800
      , height = 800
      , pad = 3
      , bgColor = 'rgb(163, 245, 207)'
      , outerCircColor = 'rgb(81, 183, 196)'
      , innerCircColor = '#fff'
      ;

  let view;
  let root;
  let focus;
  let node;
  let label;

  function build($contain) {
    const $viz = $contain.find('.js-taxon-summary')
        , data = $viz.data('json')
        ;

    root = pack(data);
    focus = root;

    const svg = d3.select($viz[0])
      .append('svg')
      .attr('viewBox', `-${width / 2} -${height / 2} ${width} ${height}`)
      .attr('width', width)
      .style('width', width)
      .attr('height', height)
      .style('height', height)
      .style('margin', '0 auto')
      .style('display', 'block')
      .style('background', bgColor)
      .on('click', (e, d) => zoom(root))
      ;

    node = svg.append('g')
      .selectAll('circle')
      .data(root.descendants().slice(1))
      .join('circle')
        .attr('fill', d => d.children ? outerCircColor : innerCircColor)
        .attr('pointer-events', d => !d.children ? 'none' : null)
        .on('click', (e, d) => { focus !== d && (zoom(d), e.stopPropagation()) })
        ;

    label = svg.append('g')
      .style('font',  '12px sans-serif')
      .attr('text-anchor', 'middle')
      .selectAll('text')
      .data(root.descendants().slice(1))
      .join('text')
        .style('fill-opacity', d => d.children ? 1 : 0)
        .style('display', d => d.children ? 'inline' : 'none')
        .text(d => `${d.data.name} (${d.value})`)
      ;

    zoomTo([root.x, root.y, root.r * 2]);
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

  function zoom(d) {
    focus = d;
    zoomTo([d.x, d.y, d.r * 2]);
    label
      .filter(function(d) { return d.parent === focus || this.style.display === "inline"; })
      .style('fill-opacity', d => d.parent === focus ? 1 : 0)
      .style('display', d => d.parent === focus ? 'inline' : 'none')
  }

  function zoomTo(v) {
    const k = width / v[2];

    view = v;

    label.attr("transform", d => `translate(${(d.x - v[0]) * k},${(d.y - v[1]) * k})`);
    node.attr("transform", d => `translate(${(d.x - v[0]) * k},${(d.y - v[1]) * k})`);
    node.attr("r", d => d.r * k);
  }

  return exports;
})({});
