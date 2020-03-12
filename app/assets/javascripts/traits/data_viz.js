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
          .attr("stroke-width", "1px")
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
    var width = 740
      , hPad = 5
      , innerWidth = width - (hPad * 2)
      , barHeight = 20
      , barSpace = 8
      , labelY = 15 
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
    buildTick(gKey, 'start', 0);
    buildTick(gKey, 'middle', maxCount / 2);
    buildTick(gKey, 'end', maxCount);

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

    function buildTick(group, textAnchor, number) {
      var x = (number / maxCount) * innerWidth + hPad
        , textX = 0
        , gTick = group.append('g')
            .attr('transform', `translate(${x}, 0)`)
        ;

      if (textAnchor == 'start') {
        textX = -3;
      } else if (textAnchor == 'end') {
        textX = 3;
      }

      gTick.append('text')
        .text(number)
        .attr('x', textX)
        .attr('y', 12)
        .attr('text-anchor', textAnchor)

      gTick.append('line')
        .attr('stroke', 'black')
        .style('stroke-width', '1px')
        .attr('x1', 0)
        .attr('x2', 0)
        .attr('y1', 15)
        .attr('y2', 30);
    }
  }

  function buildHistogram() {
    var $elmt = $('.js-value-hist')
      , data = $elmt.data('json')
      , width = 740
      , height = 500
      , bucketWidth = width / 20
      , xLineY = height - 60 
      , xLineWidth = (data.buckets.length) * bucketWidth
      , xLineX1 = (width - xLineWidth) / 2
      , xTicks = new Array(data.buckets.length + 1)
          .fill(null)
          .map((_, i) => i * data.bw + data.min)
      , yLineHeight = 400
      , tickLength = 8
      , tickTextOffset = 25 
      , axisLabelOffset = 50 
      , yAxisOffsetVert = 20
      , yAxisOffsetHoriz = 10
      , numYTicks = 10
      , yTickIncr = Math.ceil(data.maxCount / numYTicks)
      , yTicks = new Array(numYTicks)
          .fill(null)
          .map((_, i) => i * yTickIncr)
      , yTickDist = yLineHeight / (numYTicks - 1)
      ;

    var svg = d3.select('.js-value-hist')
          .append('svg')
          .attr('width', width)
          .attr('height', 400)
          .style('width', width)
          .style('height', height)
          .style('margin', '0 auto')
          .style('display', 'block')

    var gX = svg.append('g')
      .attr('transform', `translate(${xLineX1}, ${xLineY})`);

    gX.append('line')
      .attr('stroke', 'black')
      .attr('stroke-width', 1)
      .attr('x1', 0)
      .attr('x2', xLineWidth)
      .attr('y1', 0)
      .attr('y2', 0);

    // todo: i18n
    gX.append('text')
      .attr('x', xLineWidth / 2)
      .attr('y', axisLabelOffset)
      .attr('text-anchor', 'middle')
      .attr('font-size', 15)
      .text('value')

    var gTickX = gX.selectAll('.tick')
      .data(xTicks)
      .enter()
      .append('g')
        .attr('class', 'tick')
        .attr('transform', (d, i) => `translate(${bucketWidth * i}, 0)`);

    gTickX
      .append('line')
        .attr('x1', 0)
        .attr('x2', 0)
        .attr('y1', 0)
        .attr('y2', tickLength)
        .attr('stroke', 'black')
        .attr('stroke-width', 1);

    gTickX
      .append('text')
      .attr('text-anchor', 'middle')
      .attr('y', tickTextOffset)
      .text(d => d)
      
    // y axis
    // TODO: DRY
    var gY = svg.append('g')
      .attr('transform', `translate(${xLineX1 - yAxisOffsetHoriz}, ${xLineY - yAxisOffsetVert}) rotate(270, 0, 0)`)

    gY.append('line')
      .attr('stroke', 'black')
      .attr('stroke-width', 1)
      .attr('x1', 0)
      .attr('x2', yLineHeight)
      .attr('y1', 0)
      .attr('y2', 0);

    // TODO: adjust so y label shows up
    gY.append('text')
      .attr('x', yLineHeight / 2)
      .attr('y', -1 * axisLabelOffset)
      .attr('text-anchor', 'middle')
      .attr('font-size', 15)
      .text('# of records')

    var gTickY = gY.selectAll('.tick')
      .data(yTicks)
      .enter()
      .append('g')
        .attr('class', 'tick')
        .attr('transform', (d, i) => `translate(${yTickDist * i}, 0)`);

    gTickY.append('line')
      .attr('x1', 0)
      .attr('x2', 0)
      .attr('y1', 0)
      .attr('y2', -1 * tickLength)
      .attr('stroke', 'black')
      .attr('stroke-width', 1);

    gTickY
      .append('text')
      .attr('text-anchor', 'middle')
      .attr('y', -1 * tickTextOffset)
      .text(d => d);

    var gBars = svg.append('g')
      .attr('transform', `translate(${xLineX1}, ${xLineY - yAxisOffsetVert})`);

    var bar = gBars.selectAll('bar')
      .data(data.buckets)
      .enter() 
      .append('g')
        .attr('stroke', 'black')
        .attr('stroke-width', 1)
        .attr('transform', (d) => `translate(${d.index * bucketWidth}, 0)`)

    bar.append('line')
      .attr('x1', 0)
      .attr('x2', 0)
      .attr('y1', 0)
      .attr('y2', d => (-1 * yLineHeight * d.count) / data.maxCount)

    bar.append('line')
      .attr('x1', bucketWidth)
      .attr('x2', bucketWidth)
      .attr('y1', 0)
      .attr('y2', d => (-1 * yLineHeight * d.count) / data.maxCount)
  
    bar.append('line')
      .attr('x1', 0)
      .attr('x2', bucketWidth)
      .attr('y1', d => (-1 * yLineHeight * d.count) / data.maxCount)
  
      .attr('y2', d => (-1 * yLineHeight * d.count) / data.maxCount)

    bar.append('line')
      .attr('x1', 0)
      .attr('x2', bucketWidth)
      .attr('y1', 0)
      .attr('y2', 0)

  }

  exports.buildPieChart = buildPieChart;
  exports.buildBarChart = buildBarChart;
  exports.buildHistogram = buildHistogram;

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


