window.TraitDataViz = (function(exports) {
  function buildPieChart() {
    var width = 650
      , height = 300
      , margin = 20
      , radius = 120 
      , $chart = $('.js-object-pie-chart')
      , rawData = $chart.data('results')
      , promptText = $chart.data('promptText')
      , pie = d3.pie()
          .value(d => d.count)
      , dataReady = pie(rawData)
      , colorScheme = d3.scaleSequential(d3.interpolateWarm)
          .domain([0, dataReady.length - 1])
      , fontSize = 12
      ;

    var svg = d3.select('.js-object-pie-chart')
          .append('svg')
            .attr('width', width)
            .attr('height', height)
            .style('width', width)
            .style('height', height)
            .style('display', 'block')
            .style('margin', '0 auto')
      , gPie = svg.append('g')
            .attr("transform", "translate(" + width / 2 + "," + (radius + 5) + ")")
      , gSlice = gPie.append('g')
          .attr('class', 'slices')
      , gKey = svg.append('g')
      ;

    function buildKey(data) {
      var lineHeight = 16 
        , rectSize = 10
        , rectMargin = 5
        , sortedData = data.sort((a, b) => {
            if (a.data.is_other) {
              return 1;
            } else if (b.data.is_other) {
              return -1;
            } else {
              return a.data.obj_name.localeCompare(b.data.obj_name);
            }
          })
        , group
        ;

      group = gKey.selectAll('g')
        .data(sortedData, d => d.index);

      groupEnter = group.enter()
        .append('g')
        .attr('x', 0)
        .attr('y', (d, i) => i * lineHeight)
        .attr('transform', (d, i) => 'translate(0,' + i * lineHeight + ')')
        .style('cursor', 'pointer')
        .on('mouseenter', highlightSlice)
        .on('mouseleave', reset);

      groupEnter.append('rect')
            .attr('width', rectSize)
            .attr('height', rectSize)
            .attr('fill', sliceFill);

      groupEnter.append('text')
        .attr('x', rectSize + rectMargin)
        .attr('y', rectSize - 1)
        .style('font-size', fontSize)
        .text(d => d.data[d.data.label_key]);

    }

    function buildSlices(data) {
      var selection = gSlice.selectAll('path')
        .data(data, d => d.index)

      selection.enter()
        .append('path')
          .attr('d', d3.arc()
            .innerRadius(0)
            .outerRadius(radius)
          )
          .attr('fill', sliceFill) 
          .attr("stroke", "black")
          .style("stroke-width", "1px")
          //.style("opacity", 0.7)
          .style('cursor', (d) =>  {
            if (d.data.search_path) {
              return 'pointer'
            } else {
              return 'default'
            }
          })
          .on('mouseenter', highlightSlice)
          .on('mouseleave', reset)
          .on('click', (d) => {
            if (d.data.search_path) {
              window.location = d.data.search_path
            }
          });

      selection.exit().remove();
    }

    function highlightSlice(d) {
      var highlightDatum = JSON.parse(JSON.stringify(d))
        , highlightData = [highlightDatum]
        ;

      highlightDatum.data.label_key = 'prompt_text';

      gSlice
        .selectAll('path')
        .filter((slice) => { return slice.index !== d.index })
        .style('opacity', .2)

      gKey
        .selectAll('rect')
        .filter((rect) => rect.index !== d.index)
        .style('opacity', .2)

      gKey
        .selectAll('text')
        .filter((text) => text.index == d.index)
        .style('text-decoration', 'underline')

      gPie.select('.prompt')
        .text(d.data.prompt_text);
    }

    function reset() {
      gSlice
        .selectAll('path')
        .style('opacity', 1);

      gKey  
        .selectAll('rect')
        .style('opacity', 1);

      gKey
        .selectAll('text')
        .style('text-decoration', 'none')

      gPie.select('.prompt')
        .text(promptText);
    }

    function sliceFill(d) {
      return colorScheme(d.index);
    }

    function buildPrompt(text) {
      var promptMargin = 35;

      gPie
        .append('text')
        .attr('class', 'prompt')
        .attr('id', 'prompt')
        .attr('y', radius + promptMargin)
        .attr('text-anchor', 'middle')
        .style('font-size', fontSize)
        .text(text);
    }

    buildSlices(dataReady);
    buildKey(dataReady);
    buildPrompt(promptText);
  }

  exports.buildPieChart = buildPieChart;
  return exports;
})({});

$(function() {
  if ($('.js-object-pie-chart').length) {
    TraitDataViz.buildPieChart();
  }
})


