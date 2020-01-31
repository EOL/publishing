(function() {
  function buildPieChart() {
    var width = 550
      , height = width
      , margin = 100 
      , radius = Math.min(width, height) / 2 - margin
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
      , hoverIndex = null
      ;

    var svg = d3.select('.js-object-pie-chart')
          .append('svg')
            .attr('width', width)
            .attr('height', height)
          .append('g')
            .attr("transform", "translate(" + width / 2 + "," + height / 2 + ")")
      , gSlice = svg.append('g')
          .attr('class', 'slices')
      , gLabel = svg.append('g')
          .attr("font-family", "sans-serif")
          .attr("font-size", 12)
          .attr("text-anchor", "middle")
          .attr('class', 'labels')
      , gStem = svg.append('g')
          .attr('class', 'stems')
      ;

    function buildSlices(data) {
      gSlice.selectAll('path')
        .data(data)
        .enter()
          .append('path')
            .attr('d', d3.arc()
              .innerRadius(0)
              .outerRadius(radius)
            )
            .attr('fill', sliceFill) 
            .attr("stroke", "black")
            .style("stroke-width", "1px")
            .style("opacity", 0.7)
            .style('cursor', 'pointer')
            .on('mouseenter', highlightSlice)
            .on('mouseleave', reset);
    }

    function buildLabels(data) {
      var selection = gLabel
        .selectAll('text')
        .data(data, d => d.index);

      selection.enter()
        .append('text')
        .attr('transform', d => `translate(${arcLabel.centroid(d)})`)
        .text(d => d.data[d.data.label_key]);

      selection.text(d => d.data[d.data.label_key]);
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
      var highlightDatum = JSON.parse(JSON.stringify(d))
        , highlightData = [highlightDatum]
        ;

      highlightDatum.data.label_key = 'link_text';

      gSlice
        .selectAll('path')
        .filter((slice) => { return slice.index !== d.index })
        .attr('fill', disabledSliceColor);


      buildLabels(highlightData)
      buildStems(highlightData);
    }

    function reset() {
      gSlice
        .selectAll('path')
        .attr('fill', sliceFill);

      buildLabels(dataReady);
      buildStems(dataReady);
    }

    function sliceFill(d) {
      return colorScheme(d.index);
    }

    buildSlices(dataReady);
    buildStems(dataReady);
    buildLabels(dataReady);
  }

  $(function() {
    if ($('.js-object-pie-chart').length) {
      buildPieChart();
    }
  })
})();

