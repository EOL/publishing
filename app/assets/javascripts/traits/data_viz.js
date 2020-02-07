window.TraitDataViz = (function(exports) {
  function buildPieChart() {
    var width = 560
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
            .attr("transform", "translate(" + 350 + "," + (radius + 10) + ")")
      , gSlice = gPie.append('g')
          .attr('class', 'slices')
      , gKey = svg.append('g')
      ;

    function buildKey(data) {
      var lineHeight = 25
        , rectSize = 10
        , rectMargin = 5
        , group
        ;

      group = gKey.selectAll('g')
        .data(data, d => d.index)
        .enter()
        .append('g')
          .style('cursor', 'pointer')
          .on('mouseenter', highlightSlice)
          .on('mouseleave', reset);

      group.append('rect')
            .attr('x', 0)
            .attr('y', d => d.index * lineHeight)
            .attr('width', rectSize)
            .attr('height', rectSize)
            .attr('fill', sliceFill);

      group.append('text')
        .attr('x', rectSize + rectMargin)
        .attr('y', d => d.index * lineHeight + rectSize - 1)
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
      gPie
        .append('text')
        .attr('class', 'prompt')
        .attr('id', 'prompt')
        .attr('y', radius + 20)
        .attr('text-anchor', 'middle')
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


