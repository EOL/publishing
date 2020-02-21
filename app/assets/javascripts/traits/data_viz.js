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

  function buildBarChart() {
    var width = 750
      , hPad = 15
      , innerWidth = width - (hPad * 2)
      , barHeight = 30
      , barSpace = 10
      , labelY = 20
      , labelX = 10
      , keyHeight = 40
      /*
      , data = [
          { label: 'foo', count: 400 },
          { label: 'bar', count: 250 },
          { label: 'bax', count: 175 },
          { label: 'other', count: 472 }
        ].sort((a, b) => b.count - a.count)
        */
      , data = $('.js-taxon-bar-chart').data('results')
      , maxCount = data.reduce((curMax, d) => {
          return Math.max(d.count, curMax) 
        }, 0)
      , remainder = maxCount % 10
      , height = data.length * (barHeight + barSpace) - barSpace + keyHeight
      , barColors = ['#b3d7ff', '#e6f2ff']
      ;

    if (remainder > 0) {
      maxCount += (10 - remainder);
    }

    data.forEach((d) => {
      d.width = (d.count / maxCount) * innerWidth;
    });

    var svg = d3.select('.js-taxon-bar-chart')
          .append('svg')
            .attr('width', width)
            .attr('height', height)
            .style('width', width)
            .style('height', height)
            .style('display', 'block')
            .style('margin', '0 auto');

    var gKey = svg.append('g')
    buildTick(gKey, 0);
    buildTick(gKey, maxCount / 2);
    buildTick(gKey, maxCount);

    var gBar = svg.append('g')
      .attr('transform', `translate(${hPad}, ${keyHeight})`);


    var barsEnter = gBar
      .selectAll('.bar')
      .data(data)
      .enter()
      .append('g')
      .attr('class', 'bar')
      .attr('transform', (d, i) => `translate(0, ${i * (barHeight + barSpace)})`)
      .style('cursor', 'pointer')
      .on('mouseenter', (d) => {
        d3.select(d3.event.target).select('text').text(d.prompt_text);
      })
      .on('mouseleave', (d) => {
        d3.select(d3.event.target).select('text').text(d.label);
      })
      .on('click', d => window.location = d.search_path);


    barsEnter
      .append('rect')
      .attr('width', d => d.width)
      .attr('height', barHeight)
      .attr('fill', (d, i) => barColors[i % barColors.length])
    barsEnter
      .append('text')
      .text(d => d.label)
      .style('line-height', barHeight)
      .attr('x', (d) => { 
        if (widthGtHalf(d)) {
          return d.width - labelX;
        } else {
          return d.width + labelX;
        }
      })
      .attr('text-anchor', (d) => {
        if (widthGtHalf(d)) {
          return 'end';
        } else {
          return 'start';
        }
      })
      .attr('y', labelY)

    function widthGtHalf(d) {
      return d.count > maxCount / 2;
    }

    function buildTick(group, number) {
      var x = (number / maxCount) * innerWidth + hPad
        , gTick = group.append('g')
            .attr('transform', `translate(${x}, 0)`)
        ;

      gTick.append('text')
        .text(number)
        .attr('y', 12)
        .attr('text-anchor', 'middle')

      gTick.append('line')
        .attr("stroke", "black")
        .style("stroke-width", "1px")
        .attr('x1', 0)
        .attr('x2', 0)
        .attr('y1', 15)
        .attr('y2', 30);
    }
  }

  exports.buildPieChart = buildPieChart;
  exports.buildBarChart = buildBarChart;
  return exports;
})({});

$(function() {
  if ($('.js-object-pie-chart').length) {
    TraitDataViz.buildPieChart();
  }

  if ($('.js-taxon-bar-chart').length) {
    TraitDataViz.buildBarChart();
  }
})


