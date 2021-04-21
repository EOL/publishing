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
  let svg;

  function build($contain) {
    const $viz = $contain.find('.js-taxon-summary')
        , data = $viz.data('json')
        ;

    root = pack(data);
    focus = root;

    d3.select($viz[0])
      .style('width', `${width}px`)
      .style('height', `${height}px`)
      .style('position', 'relative')
      .style('margin', '0 auto')
      ;

    svg = d3.select($viz[0])
      .append('svg')
      .attr('viewBox', `-${width / 2} -${height / 2} ${width} ${height}`)
      .attr('width', width)
      .style('width', width)
      .attr('height', height)
      .style('height', height)
      .style('margin', '0 auto')
      .style('display', 'block')
      .style('background', bgColor)
      .style('cursor', 'pointer')
      .on('click', (e, d) => zoom(root))
      ;

    node = svg.append('g')
      .selectAll('circle')
      .data(root.descendants().slice(1))
      .join('circle')
        .attr('fill', d => d.children ? outerCircColor : innerCircColor)
        .on('click', handleNodeClick)
        ;

    label = svg.append('g')
      .style('font',  '12px sans-serif')
      .attr('text-anchor', 'middle')
      .attr('pointer-events', 'none')
      .selectAll('text')
      .data(root.descendants().slice(1))
      .join('text')
        .attr('id', labelId)
        .style('fill-opacity', d => d.children ? 1 : 0)
        .style('display', labelDisplay)
        .text(defaultLabelText)
      ;

    outerFilterPrompt = d3.select($viz[0])
      .append('button')
      .style('position', 'absolute')
      .style('top', '5px')
      .style('right', '5px')
      .style('text-anchor', 'end')
      .style('padding', '2px 4px')
      .style('font', 'bold 14px sans-serif')
      .style('display', 'none')

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

    if (focus !== root && focus.children) {
      outerFilterPrompt.html(`click to filter by '${d.data.name}'`);
      outerFilterPrompt.style('display', 'block');
      outerFilterPrompt.on('click', () => window.location = d.data.searchPath);
    } else {
      outerFilterPrompt.style('display', 'none');
    }

    const transition = svg.transition()
        .duration(750)
        .tween("zoom", d => {
          const i = d3.interpolateZoom(view, [focus.x, focus.y, focus.r * 2]);
          return t => zoomTo(i(t));
        });

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
    node
      .attr('pointer-events', d => d.parent && d.parent === focus ? null : 'none')
      .on('mouseover', handleNodeMouseover)
      .on('mouseout', handleNodeMouseout)
      ;
  }

  function handleNodeClick(e, d) {
    if (d !== focus) {
      if (d.children) {
        zoom(d); 
      } else {
        window.location = d.data.searchPath;
      }

      e.stopPropagation();
    }
  }

  function handleNodeMouseover(e, d) {
    d3.select(this).attr('stroke', '#000');

    if (!d.children) {
      label.style('display', 'none');

      d3.select(`#${labelId(d)}`)
        .style('display', 'inline')
        .append('tspan')
        .attr('x', 0)
        .attr('dy', 13)
        .text('click to filter');
    }
  }

  function handleNodeMouseout(e, d) {
    d3.select(this).attr('stroke', null)

    if (!d.children) {
      label.style('display', labelDisplay);

      d3.select(`#${labelId(d)}`)
        .text(defaultLabelText);
    }
  }

  function labelId(d) {
    return `label-${d.data.pageId}`;
  }

  function defaultLabelText(d) {
    let text = d.data.name;
    
    // don't show value for parents -- it's potentially inaccurate since it's the sum of a *sample* of children
    if (!d.children) {
      text += ` (${d.value})`; 
    }

    return text;
  }

  function labelDisplay(d) {
    return d.parent === focus ? 'inline' : 'none';
  }

  return exports;
})({});
