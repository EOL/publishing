(function() {
  function buildPieChart() {
    var width = 450
      , height = width
      , margin = 50
      , radius = Math.min(width, height) / 2 - margin
      ;

    var svg = d3.select('.js-object-pie-chart')
      .append('svg')
        .attr('width', width)
        .attr('height', height)
      .append('g')
        .attr("transform", "translate(" + width / 2 + "," + height / 2 + ")");

    // Create dummy data
    var data = $('.js-object-pie-chart').data('results')
      ;
    
    // Compute the position of each group on the pie:
    var pie = d3.pie()
      .value(function(d) { return d.count; })
    var dataReady = pie(data);

    var color = d3.scaleSequential(d3.interpolateWarm)
      .domain([0, dataReady.length - 1])

    // Build the pie chart: Basically, each part of the pie is a path that we build using the arc function.
    svg
      .selectAll('whatever')
      .data(dataReady)
      .enter()
      .append('path')
      .attr('d', d3.arc()
        .innerRadius(0)
        .outerRadius(radius)
      )
      .attr('fill', function(d) { 
        console.log(d);
        console.log(d.index);
        console.log(color(d.index));
        return color(d.index) 
      })
      .attr("stroke", "black")
      .style("stroke-width", "1px")
      .style("opacity", 0.7)
  }

  $(function() {
    if ($('.js-object-pie-chart').length) {
      buildPieChart();
    }
  })
})();
