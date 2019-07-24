$(function() {
  function createViz($trophicWeb) {
    var sitePrefix = ''; //"https://beta.eol.org";

    var $container = $trophicWeb.find('.js-network-contain')
      , $dimmer = $trophicWeb.find('.dimmer')
      ;

    var gColor = ["source", "predator", "prey", "", "", "competitor"]

    var expandNodeIds = {};

    //graph
    var graph;

    //for animation purpose
    var transition = false
      , resizedInTransition = false
      ;
      
    //node positions
    var predPos = []
      , preyPos = []
      , compPos = []
      , sourcePos = []
      ;
      
    //Node number limit
    var nLimit = 7;

    //network graph window #networkSvg
    var sourceX
      , sourceY
      , radius = 6
      , source_radius = 30
      ;
      
    //node colors
    var color = d3.scaleOrdinal(d3.schemeSet3);
      color(1);
      color(2);
      color(3);
      color(4);
      color(5);

    //svg selection and sizing  
    var s = select(".js-network-svg")
      , svg = s.append("g")
      , linksGroup = svg.append('g').attr('id', 'links')
      , nodesGroup = svg.append('g').attr('id', 'nodes')
      , tooltip = select(".js-tooltip")
      , tooltipSvg = select(".js-tooltip-svg")
      ;
        
    var zoom = d3.zoom().scaleExtent([.5, 3])
      .on("zoom", function() {
        svg.attr("transform", d3.event.transform);
      });
    s.call(zoom)
     .on("wheel.zoom", null);
      
    select(".js-reset").on("click", reset);

    select(".js-zoom-in").on("click", function() {
      zoom.scaleBy(s.transition().duration(100), 1.1);
    }); 

    select(".js-zoom-out").on("click", function() {
        zoom.scaleBy(s.transition().duration(100), 0.9);
    });

    //legend label HTML
    var sequentialScale = tooltipSvg.append("g")
      .attr("class", "legendarray")
      .append("g")
      .attr("class", "legendCells")
      .attr("transform", "translate(0, 12.015625)");

    var predLegend = sequentialScale.append("g")
      .attr("class", "cell")
      .attr("transform", "translate(0,0)");
      
    predLegend  
      .append("rect").attr("class", "watch")
      .attr("height", 15).attr("width", 30)
      .attr("style", "fill: rgb(141, 211, 199);");

    predLegend
      .append("text")
      .attr("class", "label")
      .attr("transform", "translate(40, 12.5)")
      .text("Predator");

    var preyLegend = sequentialScale.append("g")
      .attr("class", "cell")
      .attr("transform", "translate(0,20)");
      
    preyLegend  
      .append("rect")
      .attr("class", "watch")
      .attr("height", 15)
      .attr("width", 30)
      .attr("style", "fill: rgb(255, 255, 179);");

    preyLegend
      .append("text")
      .attr("class", "label")
      .attr("transform", "translate(40, 12.5)")
      .text("Prey");
      
    var compLegend = sequentialScale.append("g")
      .attr("class", "cell").attr("transform", "translate(0,40)");
      
    compLegend  
      .append("rect")
      .attr("class", "watch")
      .attr("height", 15).attr("width", 30)
      .attr("style", "fill: rgb(128, 177, 211);");

    compLegend
      .append("text")
      .attr("class", "label")
      .attr("transform", "translate(40, 12.5)")
      .text("Competitor");

    var pattern = svg.selectAll('.pattern');

    var marker = svg.selectAll('.marker')
      .data(["arrow", "longer"])
      .enter().append('marker')
      .attr("id", function(d) {return d;})
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", function(d) {
        if(d == "arrow") {
          return 20;
        } else {
          return 60;
        }
      })
      .attr("refY", 0)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .attr("fill", "#9b9b9b")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .style("stroke", "#9b9b9b");


    //initialize first graph
    calculatePositions();
    initializeGraph();

    function dataUrl(pageId) {
      return sitePrefix + "/api/pages/" + pageId + "/pred_prey.json"
    }

    function shouldKeepNode(n, counts, keepIds) {
      var keep = (
        !keepIds[n.id] && (
          n.group === 'source' ||
          n.group === 'competitor' && counts['competitor'] < 10 ||
          (!counts[n.group] || counts[n.group] < nLimit)
        )
      )

      if (keep) {
        counts[n.group] = (counts[n.group] || 0) + 1;
        keepIds[n.id] = true;
      }

      return keep;
    }

    function pruneGraph(graph, prevGraph) {
      var keepIds = {}
        , counts = {}
        , nodesById = buildNodesById(graph.nodes)
        , newNodes
        ;

      newNodes = prevGraph ? 
        prevGraph.nodes
          .map(n => {
            var newNode = nodesById[n.id];

            if (newNode && isExpandNode(n)) {
              expandNodeIds[n.id] = true;
            }

            return newNode;
          })
          .filter(n => (n && shouldKeepNode(n, counts, keepIds))) :
        [];

      graph.nodes = newNodes.concat(graph.nodes.filter(n => shouldKeepNode(n, counts, keepIds)))

      graph.links = graph.links.filter(l => {
        return keepIds[l.source] && keepIds[l.target];
      });

      graph.links.forEach(l => {
        l.source = nodesById[l.source];
        l.target = nodesById[l.target];
      });
    }

    function buildNodesById(nodes) {
      return nodes.reduce((obj, node) => {
        obj[node.id] = node;
        return obj;
      }, {})
    }

      
    function initializeGraph() {
      handleData(JSON.parse(JSON.stringify($trophicWeb.data('init'))), false);
    }

    function loadData(eolId, animate) {
      $dimmer.addClass('active');
      //query prey_predator json
      d3.json(dataUrl(eolId), (err, g) => {
        if (err) throw err;
        handleData(g, animate);
      });
    }

    function handleData(g, animate) {
      var prevGraph = graph;
      graph = g;
      pruneGraph(graph, prevGraph);
      updatePositions();
      updateGraph(animate);
      $dimmer.removeClass('active');
    }

    function createNodes(animate) {
      var className = 'node'
        , nodes = nodesGroup.selectAll(`.${className}`).data(graph.nodes, d => d.id)
        , nodesEnter
        ;

      // EXIT
      nodes.exit().remove();

      // UPDATE
      nodes.select('g').attr('opacity', 1);
      
      // ENTER
      nodesEnter = nodes.enter()
        .append('g')
        .attr('class', className)
        .attr('id', function(d) { return 'node-' + d.id.toString() })
        .attr('transform', d => `translate(${d.x},${d.y})`)

      if (animate) {
        nodesEnter.attr('opacity', 0);
      }

      nodesEnter.call(
        d3.drag().subject(function() { 
          var t = d3.select(this);
          var tr = getTranslation(t.attr("transform"));
   
          return {
            x: t.attr("x") + tr[0],
            y: t.attr("y") + tr[1]
          };
        })
        .on('drag', function(d,i) {
          if (!transition) {
            d3.select(this).attr("transform", function(d,i) {
              d.x = d3.event.x;
              d.y = d3.event.y;
              return "translate(" + [ d3.event.x, d3.event.y ] + ")";
            });
         
            svg.selectAll('.link').filter(l => (l.source === d))
              .transition().duration(1).attr("x2", d3.event.x).attr("y2", d3.event.y);
            svg.selectAll('.link').filter(l => (l.target === d))
              .transition().duration(1).attr("x1", d3.event.x).attr("y1", d3.event.y);
          }
        })
      );
      
      //APPEND IMAGE
      nodesEnter
        .append("svg:pattern")
          .attr("id", function(d) { return patternId(d); })
          .attr("width", "100%")
          .attr("height", "100%")
          .attr("patternContentUnits", "objectBoundingBox")
          .attr("preserveAspectRatio", "xMidYMid slice")
          .attr("viewBox", "0 0 1 1")
          .append("svg:image")
            .attr("xlink:href", function(d) { return d.icon; })
            .attr("width", "1")
            .attr("height", "1")
            .attr("preserveAspectRatio", "xMidYMid slice");

      nodesEnter
        .on("click", d => {
          appendJSON(d);
        })
        .on('mouseover.fade', fade(0.1))
        .on('mouseout.fade', fade(1))
        .on('mouseover.tooltip', function(d) {
          tooltip
            .style("display", "inline-block")
            .style("opacity", .9);
          tooltip.html("<p style=\"font-size: 15px; color:"+ color(gColor.indexOf(d.group))+"; font-style: italic;\"><a href=\"https://eol.org/pages/"+d.id+"\" style=\"color: black; font-weight: bold; font-size: 15px\" target=\"_blank\">"+d.label+ "</a><br /><p>" + d.groupDesc + "</p><img src=\""+ d.icon+ "\" width=\"190\"><p>");
        });
      
      
      // APPEND/UPDATE CIRCLE
      nodesEnter.append('circle').merge(nodes.select('circle'))
        .attr("r", function(d) {
          if (isExpandNode(d)) {
            return source_radius;
          } else {
            return radius;
          }
        })  
        .attr("fill", function(d) {
          if (isExpandNode(d)) {
            return 'url(#' + patternId(d) + ')';
          }
          else if (d.group == "predator" | d.group =="prey" | d.group =="competitor") {
            return color(gColor.indexOf(d.group));
          }
          else if (d.group%2==0) { return color(1);}
          else {return color(2);}
        });

      // APPEND/UPDATE LABEL
      nodesEnter.append('text').merge(nodes.select('text'))
        .attr('x', function(d) {
          if (isExpandNode(d)){
            return 32;
            
          } else {
            return 0; 
          }
        })
        .attr('y', function(d) {
          if(isExpandNode(d)){
            return 0; 
          }else {
            return 15;
          }
        })
        .attr('dy', '.35em')
        .attr("fill", 'black')
        .attr("font-family", "verdana")
        .attr("font-size", "10px")
        .attr("text-anchor",function(d) {
          if(isExpandNode(d)) {
            return "left";
          } else {
            return "middle";
            
          }
        })
        .text(function(d) {return d.label;});

      return {
        nodes: nodes,
        nodesEnter: nodesEnter
      };
    }


    function patternId(d) {
      return 'pattern-' + d.id.toString();
    }

    function getTranslation(transform) {
      // Create a dummy g for calculation purposes only. This will never
      // be appended to the DOM and will be discarded once this function
      // returns.
      var g = document.createElementNS("http://www.w3.org/2000/svg", "g");

      // Set the transform attribute to the provided string value.
      g.setAttributeNS(null, "transform", transform);

      // consolidate the SVGTransformList containing all transformations
      // to a single SVGTransform of type SVG_TRANSFORM_MATRIX and get
      // its SVGMatrix.
      var matrix = g.transform.baseVal.consolidate().matrix;

      // As per definition values e and f are the ones for the translation.
      return [matrix.e, matrix.f];
    }

    function calculatePositions() {
      width = $container.width();
      height = $container.height();
      sourceX = (width - 100) / 2;
      sourceY = height / 2;

      s.attr("width", width)
       .attr("height", height);

      svg.attr("width", width)
         .attr("height", height);  

      sourcePos = [];
      preyPos = [];
      predPos = [];
      
      var add, preyAngle, predAngle;

      //alternative heights (display purpose)
      var radius = height / 2.5 + 20
        , middleIndex = Math.floor(nLimit / 2)
        ;
      
      sourcePos = [sourceX, sourceY];
      
      for (var i = 0; i < nLimit ; i++) {
        if (nLimit == 1){
          add = 1 / 8;
          predAngle = (7 / 6 + add) * Math.PI;
        } else {
          add = 2 / (3 * (nLimit - 1));
          predAngle = (7 / 6 + (i) * add) * Math.PI;
        }

        preyAngle = (1/6 + ((i)*add)) * Math.PI;
        preyPos.push([((radius * Math.cos(preyAngle)) + sourceX),
        ((radius * Math.sin(preyAngle)) + sourceY)]);  
        
        predPos.push ([((radius * Math.cos(predAngle)) + sourceX),
        ((radius * Math.sin(predAngle)) + sourceY)]);
      }
    }

    function linkId(d) {
      return d.source.id + '-' + d.target.id; 
    }

    function isExpandNode(n) {
      return expandNodeIds[n.id] || n.group === 'source';
    }

    function updateGraph(animate) {
      var links = linksGroup.selectAll('.link').data(graph.links, d => linkId(d))
        , linksEnter
        ;

      links.exit().remove();

      linksEnter = links.enter()
        .append('line')
        .attr('class', 'link')
        .attr("x1", function(d) {return d.target.x;})
        .attr("y1", function(d) {return d.target.y;})
        .attr("x2", function(d) {return d.source.x;})
        .attr("y2", function(d) {return d.source.y;});

      linksEnter.merge(links)
        .attr('marker-end', (d) => {
          if (isExpandNode(d.source)) {
            return "url(#longer)";
          } else {
            return "url(#arrow)";
          }
        });

      if (animate) {
        linksEnter.attr('opacity', 0);
      }

      nodeResult = createNodes(animate);

      transition = transition || animate;

      nodeResult.nodes.transition()
        .duration(animate ? 5000 : 1)
        .attr("transform",  d => `translate(${d.x},${d.y})`)
        .on('end', () => {
          if (animate) {
            //new nodes and links appear after transition
            nodeResult.nodesEnter
              .transition()
              .duration(animate ? 1000 : 1)
              .attr("opacity", 1);

            linksEnter
              .transition()
              .duration(animate ? 1000 : 1)
              .attr("opacity", 1)
              .on('end', () => { 
                transition = false 

                if (resizedInTransition) {
                  handleResize();
                  resizedInTransition = false;
                }
              });
          }
        });

      links.transition().duration(animate ? 5000 : 1).attr("x1", function(d) { return d.target.x; }).attr("y1", function(d) { return d.target.y; }).attr("x2", function(d) { return d.source.x; }).attr("y2", function(d) { return d.source.y; })
    }

    // new data
    function appendJSON(d) {
      loadData(d.id, true);
    }

    function updatePositions() {
      //make a copy of an array
      var tmpPreyPos, tmpPredPos, tmpCompPos;
      var competitors = []
        , others = []
        ;

      graph.nodes.forEach(node => {
        if (node.group === 'competitor') {
          competitors.push(node);
        } else {
          others.push(node);
        }
      });
      
      tmpPreyPos = preyPos.slice();
      tmpPredPos = predPos.slice();
      
      others.forEach(node => {
        if (node.group == "source") {
          node.x = sourcePos[0];
          node.y = sourcePos[1];
        } else if (node.group == "predator") {
          var middle = tmpPredPos[Math.floor(tmpPredPos.length / 2)];
          var index = tmpPredPos.indexOf(middle);
          
          node.x = middle[0];
          node.y = middle[1];
        
          if (index > -1) {
            tmpPredPos.splice(index, 1);
          }
        } else if (node.group == "prey") {
          if (tmpPreyPos.length != 0) {
            var middle = tmpPreyPos[Math.floor(tmpPreyPos.length / 2)];
            var index = tmpPreyPos.indexOf(middle);

            node.x = middle[0];
            node.y = middle[1];
            
            if (index > -1) {
              tmpPreyPos.splice(index, 1);
            }
          }
        }
      });
      
      if (competitors.length) {
        var extra = 5;
        var gap = (width - 100) / (competitors.length + extra);
        compPos = [];
        
        for(var i = 0; i < competitors.length + extra; i++) {
          var value = 100 + (i * gap);
          compPos.push(value);
        }
        tmpCompPos = compPos.slice();
        
        for (var i = 0; i < extra; i++) {
          tmpCompPos.splice(Math.floor(tmpCompPos.length / 2), 1);  
        }
        
        var varHeight = 30
          , varHeightCoefs = [0, -1, 0, 1]
          ;

        $(competitors).each((i, c) => {
          var prey = firstPreyForCompetitor(c);

          if(!prey || prey.x < width / 2) { // XXX: there should always be prey for competitors, but occasionally there's an error
            c.x = tmpCompPos[0];
            tmpCompPos.splice(0, 1);
          } else {
            var endIndex = tmpCompPos.length - 1;
            c.x = tmpCompPos[endIndex];
            tmpCompPos.splice(endIndex, 1); 
          }

          c.y = sourceY + (varHeight * varHeightCoefs[i % varHeightCoefs.length]);
        });
      }
    }

    function firstPreyForCompetitor(c) {
      var link = graph.links.find((l) => {
        return l.source === c;
      });
      
      return link && link.target;
    }

    function fade(opacity) {
      return d => {
        if(!(transition)) {
          var allNodes = nodesGroup
                .selectAll('.node')
            , allLinks = linksGroup
                .selectAll('.link')
            ;

          allNodes.filter(o => isConnected(d, o) )
            .attr('opacity', 1);
          allNodes.filter(o => !isConnected(d, o) )
            .attr('opacity', opacity);
          allLinks.filter(o => (o.source === d || o.target === d))
            .style('opacity', 1);
          allLinks.filter(o => (o.source !== d && o.target !== d))
            .style('opacity', opacity);
        }
      };
    }

    function isConnected(a, b) {
      return a === b || graph.links.find(l => {
        return (
          (l.source === a && l.target === b) ||
          (l.source === b && l.target === a)
        );
      });
    }

    function select(selector) {
      return d3.select('.js-trophic-web ' + selector);
    }

    function reset() {
      s.call(zoom.transform, d3.zoomIdentity);
      graph = null;
      expandNodeIds = {};
      nodesGroup.selectAll('.node').data([]).exit().remove();
      linksGroup.selectAll('.link').data([]).exit().remove();
      initializeGraph();
    }

    function handleResize() {
      if (transition) {
        resizedInTransition = true;
      } else {
        calculatePositions();
        updatePositions();
        updateGraph(false);
      }
    }

    $(window).resize(handleResize);
  }

  var $trophicWeb = $('.js-trophic-web');

  if ($trophicWeb.length) {
    createViz($trophicWeb);
  }
});
