window.TraitDataViz = (function(exports) {
  function buildPieChart() {
    var width = 800 // defaults, these are adjusted later
      , height = 350 // ""
      , margin = 20
      , radius = 130 
      , promptPadTop = 50
      , promptPadBot = 10
      , piePad = 30
      , $chart = $('.js-object-pie-chart')
      , rawData = $chart.data('results')
      , promptText = $chart.data('promptText')
      , pie = d3.pie()
          .value(d => d.count)
      , dataReady = pie(rawData)
      , colorScheme = d3.scaleSequential(d3.interpolateWarm)
          .domain([0, dataReady.length - 1])
      , fontSize = 12
      , prompt
      ;

    console.log(rawData);

    var svg = d3.select('.js-object-pie-chart')
          .append('svg')
            .attr('width', width)
            .attr('height', height)
            .style('width', width)
            .style('height', height)
            .style('display', 'block')
            .style('margin', '0 auto')
      , gPie = svg.append('g')
      , gSlice = gPie.append('g')
          .attr('class', 'slices')
      , gKey = svg.append('g')
      ;

    setPieTranslate();

    function buildKey(data) {
      var lineHeight = 16 
        , rectSize = 10
        , rectMargin = 5
        // unused, for now. Swap in if you want alphabetical key.
        , sortedData = data.sort((a, b) => {
            /*
            if (a.data.is_other) {
              return 1;
            } else if (b.data.is_other) {
              return -1;
            } else {
              return a.data.label.localeCompare(b.data.label);
            }
            */
            return b.index - a.index
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
        .style('cursor', cursor)
        .on('mouseenter', highlightSlice)
        .on('mouseleave', reset)
        .on('click', handleClick)

      groupEnter.append('rect')
            .attr('width', rectSize)
            .attr('height', rectSize)
            .attr('fill', sliceFill);

      groupEnter.append('text')
        .attr('x', rectSize + rectMargin)
        .attr('y', rectSize - 1)
        .style('font-size', fontSize)
        .text(d => d.data.label) 

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
          .style('cursor', cursor)
          .on('mouseenter', highlightSlice)
          .on('mouseleave', reset)
          .on('click', handleClick);

      selection.exit().remove();
    }

    function cursor(d) {
      return d.data.search_path ? 'pointer' : 'default';
    }

    function handleClick(d) {
      if (d.data.search_path) {
        window.location = d.data.search_path
      }
    }

    function highlightSlice(d) {
      var highlightDatum = JSON.parse(JSON.stringify(d))
        , highlightData = [highlightDatum]
        ;

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

      prompt.text(d.data.prompt_text);
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

      prompt.text(promptText);
    }

    function sliceFill(d) {
      return colorScheme(d.index);
    }

    function adjustLayout() {
      var pieRect = gPie.node().getBoundingClientRect()
        , keyRect = gKey.node().getBoundingClientRect()
        ;

      width = keyRect.width + piePad + pieRect.width
      height = Math.max(pieRect.height, keyRect.height) + promptPadTop + promptPadBot; 

      svg
        .attr('width', width)
        .style('width', width);

      svg
        .attr('height', height)
        .style('height', height);
        
      setPieTranslate();
      prompt
        .attr('x', width / 2)
        .attr('y', height - promptPadBot)
    }

    function setPieTranslate() {
      gPie.attr("transform", "translate(" + (width - radius - 1) + "," + (radius + 1) + ")");
    }

    function buildPrompt(text) {
      var promptMargin = 35;

      prompt = svg
        .append('text')
        .attr('class', 'prompt')
        .attr('id', 'prompt')
        .attr('x', width / 2)
        .attr('y', height - 20)
        .attr('text-anchor', 'middle')
        .style('font-size', fontSize)
        .text(text);
    }

    buildSlices(dataReady);
    buildKey(dataReady);
    buildPrompt(promptText);
    adjustLayout();
  }

  exports.buildPieChart = buildPieChart;
  return exports;
})({});

$(function() {
  if ($('.js-object-pie-chart').length) {
    TraitDataViz.buildPieChart();
  }
})


