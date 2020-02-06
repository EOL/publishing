(function() {
  function buildPieChart() {
    var width = 800
      , height = 300
      , margin = 20
      , radius = 120 
      , rawData = $('.js-object-pie-chart').data('results')
      , pie = d3.pie()
          .value(d => d.count)
      , dataReady = pie(rawData)
      , colorScheme = d3.scaleSequential(d3.interpolateWarm)
          .domain([0, dataReady.length - 1])
      , disabledSliceColor = "#555"
      , labelRadius = radius * 1.4
      , arcLabel = d3.arc().innerRadius(labelRadius).outerRadius(labelRadius)
      , stemInnerRadius = radius * 1.1
      , stemOuterRadius = radius * 1.3
      ;

    var svg = d3.select('.js-object-pie-chart')
          .append('svg')
            .attr('width', width)
            .attr('height', height)
      , gPie = svg.append('g')
            .attr("transform", "translate(" + width / 1.5 + "," + height / 2 + ")")
      , gSlice = gPie.append('g')
          .attr('class', 'slices')
      , gLabel = gPie.append('g')
          .attr("font-family", "sans-serif")
          .attr("font-size", 12)
          .attr("text-anchor", "middle")
          .attr('class', 'labels')
      , gStem = gPie.append('g')
          .attr('class', 'stems')
      , gKey = svg.append('g')
      ;

    function buildKey(data) {
      var lineHeight = 25
        , rectSize = 10
        , rectMargin = 5
        ;

      gKey.selectAll('rect')
        .data(data)
        .enter()
        .append('rect')
        .attr('x', 0)
        .attr('y', d => d.index * lineHeight)
        .attr('width', rectSize)
        .attr('height', rectSize)
        .attr('fill', sliceFill);

      
      gKey.selectAll('text')
        .data(data)
        .enter()
        .append('text')
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
              console.log(d);
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

    function buildLabels(data) {
      var selection = gLabel
        .selectAll('text')
        .data(data, d => d.index);


      selection.enter()
        .append('text')
        .attr('transform', (d) => `translate(${arcLabel.centroid(d)})`)
        .text(d => d.data[d.data.label_key])
        .call(wrap, 50)

      selection.text(d => d.data[d.data.label_key]).call(wrap, 50)
      selection.exit().remove();
    }

    function buildStems(data) {
      var stemData = data.map((d) => {
        var angle = (d.endAngle + d.startAngle) / 2;

        return {
          startAngle: angle,
          endAngle: angle,
          index: d.index
        }
      });

      var update = gStem
        .selectAll('path')
        .data(stemData, d => d.index);

      update.enter()
        .append('path')
          .attr('d', d3.arc()
            .innerRadius(stemInnerRadius)
            .outerRadius(stemOuterRadius)
          )
          .attr("stroke", "black")
          .style("stroke-width", "1px")
          .style("opacity", 0.7);

      update.exit().remove();
    }

    function highlightSlice(d) {
      if (!d.data.search_path) {
        return;
      }

      var highlightDatum = JSON.parse(JSON.stringify(d))
        , highlightData = [highlightDatum]
        ;

      highlightDatum.data.label_key = 'link_text';

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
      //buildSlices(highlightData);


      //buildLabels(highlightData)
      //buildStems(highlightData);
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

      //buildLabels(dataReady);
      //buildStems(dataReady);
    }

    function sliceFill(d) {
      return colorScheme(d.index);
    }

    buildSlices(dataReady);
    buildKey(dataReady);

    //buildStems(dataReady);
    //buildLabels(dataReady);
  }

  // from https://bl.ocks.org/mbostock/7555321
  function wrap(text, width) {
    text.each(function() {
      var text = d3.select(this),
          words = text.text().split(/\s+/).reverse(),
          word,
          line = [],
          lineNumber = 0,
          lineHeight = 1.1, // ems
          tspan = text.text(null).append("tspan").attr("x", 0).attr("y", 0);

      while (word = words.pop()) {
        line.push(word);
        tspan.text(line.join(" "));

        if (tspan.node().getComputedTextLength() > width && line.length > 1) {
          line.pop();
          tspan.text(line.join(" "));
          line = [word];
          tspan = text.append("tspan").attr("x", 0).attr("y", 0).attr("dy", ++lineNumber * lineHeight + "em").text(word);
        }
      }
    });
  }

  $(function() {
    if ($('.js-object-pie-chart').length) {
      buildPieChart();
    }
  })
})();

