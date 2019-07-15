$(function() {
  function createViz($container) {
    var sitePrefix = "https://beta.eol.org";

    //new data
    var nodeIDList = []
      , linkIDList = []
      ;

    //graph
    var graph
      , node
      , link
      , new_node
      , existing_node
      , existing_link
      , new_link
      ;

    //for animation purpose
    var source_nodes = []
      , existing_nodes=[]
      , new_nodes=[]
      , hiding_nodes=[]
      , existing_links = []
      , new_links = []
      , transition = false
      ;
      
    //node positions
    var curSource
      , predPos = []
      , preyPos = []
      , compPos = []
      , sourcePos= []
      ;
      
    var compList = [];

    //Node number limit
    var nLimit = 7;

    //network graph window #networkSvg
    var width
      , height
      , sourceX
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
      , tooltip = select(".js-tooltip")
      , tooltipSvg = select(".js-tooltip-svg")
      ;
        
    var zoom = d3.zoom().scaleExtent([1, 3])
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


    node = svg.selectAll('.node');
    new_node = svg.selectAll('.new_node');
    existing_node =svg.selectAll('.existing_node');
    new_link = svg.selectAll('.new_link');
    existing_link =svg.selectAll('.existing_link');
    link = svg.selectAll('.line');
    marker = svg.selectAll('marker');

    // force simulation initialization
    var simulation = d3.forceSimulation()
      .force("link", d3.forceLink()
        .id(function(d) { return d.id; }))
      .force("charge", d3.forceManyBody()
        .strength(function(d) { return -500;}))

    //initialize first graph
    initializeGraph($('.js-trophic-web').data('pageId'));

    function dataUrl(pageId) {
      return sitePrefix + "/api/pages/" + pageId + "/pred_prey.json"
    }
      
    function initializeGraph(eol_id){
      //calculate prey and predator positions (according to the source node coordinates)
      calculatePositions();
      
      //query prey_predator json
      d3.json(dataUrl(eol_id), function(err, g) {
        if (err) throw err;
        
        graph = g;
        graph.nodes[0].x = sourceX;
        graph.nodes[0].y = sourceY;
      
        //initialize the first source node
        source_nodes.push(graph.nodes[0].id);
        
        //display tooltip
        tooltip
          .style("display", "inline-block")
          .style("opacity", .9);
        tooltip.html("<p style=\"font-size: 15px; color:"+ color(0)+"; font-style: italic;\"><a href=\"https://eol.org/pages/"+graph.nodes[0].id+"\" style=\"color: black; font-weight: bold; font-size: 15px\" target=\"_blank\">"+graph.nodes[0].label+ "</a><br /><p>" + graph.nodes[0].groupDesc + "</p><img src=\""+ graph.nodes[0].icon+ "\" width=\"190\"><p>");
      
        graph.nodes.forEach(n => {
          n.px = n.x;
          n.py = n.y;
          existing_nodes.push(n);
          if(!(nodeIDList.includes(n.id.toString()))){
            nodeIDList.push(n.id.toString());}
        });
        
        graph.links.forEach(l => {
          existing_links.push(l);
          if(!(linkIDList.includes([l.source.toString()+l.target.toString()]))) {
            linkIDList.push([l.source.toString()+l.target.toString()]);
          }
        });
        
        simulation.nodes(graph.nodes);
        simulation.force("link").links(graph.links);

        setVisibilityOfNodesAndLinks(graph, graph.nodes[0]);
        updateCoordinates();
        updateGraph();
        transition=false;
        
        });
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
          //add = 1/((nLimit-1)*2);
          add = 2 / (3 * (nLimit - 1));
          //predAngle = (7/6) * Math.PI;
          predAngle = (7 / 6 + (i) * add) * Math.PI;
        }

        preyAngle = (1/6 + ((i)*add)) * Math.PI;
        preyPos.push([((radius * Math.cos(preyAngle)) + sourceX),
        ((radius * Math.sin(preyAngle)) + sourceY)]);  
        
        predPos.push ([((radius * Math.cos(predAngle)) + sourceX),
        ((radius * Math.sin(predAngle)) + sourceY)]);
      }

      simulation.force("center", d3.forceCenter(width / 2, height / 2));
    }

    function updateGraph() {
      transition = true;
      var gColor = ["source", "predator", "prey", "", "", "competitor"];   
      
      //copy nodes
      var tmp_eNodes = existing_nodes.slice();
      var tmp_nNodes = new_nodes.slice();
      var tmp_hNodes = hiding_nodes.slice();
      var currentNodes = tmp_eNodes.concat(tmp_nNodes);
      var tmp_eLinks = existing_links.slice();
      var tmp_nLinks = new_links.slice();
      
      //clear previous items
      existing_nodes=[];
      new_nodes = [];
      hiding_nodes = [];
      existing_links = [];
      new_links = [];

      currentNodes.forEach(node => {
        if(node.show) {
          existing_nodes.push(node);
        } else {
          hiding_nodes.push(node);
        }
      });
      
      tmp_hNodes.forEach(node=> {
        if(node.show) {
          new_nodes.push(node);
        } else {
          hiding_nodes.push(node);
        }
      });

      graph.links.filter(n => n.show).forEach(l =>{
        if(existing_nodes.includes(l.source) && existing_nodes.includes(l.target)){
          existing_links.push(l);
        } else {
          new_links.push(l);    
        }
      });
      
      
        //EXIT-Remove previous nodes/links
      svg.selectAll('line').data(graph.links.filter(n=>{n.show})).exit().remove();
      svg.selectAll('.node').data(new_node).exit().remove();
      svg.selectAll('.new_node').data(new_node).exit().remove();
      svg.selectAll('.existing_node').data(existing_node).exit().remove();
      
      existing_link = svg.selectAll('.line')
      .data(existing_links, function(d) { return d.id;})
      .enter().append('line')
      .attr('class', 'link')
      .attr("marker-end", function(d) { 
        if(source_nodes.includes(d.target.id)){
          return "url(#longer)";
        } else {
          return "url(#arrow)";
        }
      })
      .attr("x1", function(d) {return d.source.px;})
      .attr("y1", function(d) {return d.source.py;})
      .attr("x2", function(d) {return d.target.px;})
      .attr("y2", function(d) {return d.target.py;});
      
      new_link = svg.selectAll('.new_link')
      .data(new_links, function(d) { return d.id;})
      .enter().append('line')
      .attr('class', 'new_link')
      .attr('opacity', 0)
      .attr("marker-end", function(d) { 
        if(source_nodes.includes(d.target.id)){
          return "url(#longer)";
        } else {
          return "url(#arrow)";
        }
      })
      .attr("x1", function(d) {return d.source.nx;})
      .attr("y1", function(d) {return d.source.ny;})
      .attr("x2", function(d) {return d.target.nx;})
      .attr("y2", function(d) {return d.target.ny;});
      

      new_node = svg.selectAll('.new_node')
      //UPDATE
      .data(new_nodes)
      .enter().append('g')
      .attr('class', 'new_node')
      .attr("id", function(d) {return d.label.replace(/\s/g,'');})
      .attr("x", function(d) {return d.fx;})
      .attr("y", function(d) {return d.fy;})
      .attr("transform", d => `translate(${d.nx},${d.ny})`)
      .attr('opacity', 0);
      
      //APPEND IMAGE
      new_node.append("svg:pattern")
      .attr("id", function(d) {return d.id.toString();})
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("patternContentUnits", "objectBoundingBox")
      .attr("preserveAspectRatio", "xMidYMid slice")
      .attr("viewBox", "0 0 1 1")
        .append("svg:image")
        .attr("xlink:href", function(d) {return d.icon;})
        .attr("width", "1")
        .attr("height", "1")
      .attr("preserveAspectRatio", "xMidYMid slice");
      
      //APPEND CIRCLE
      new_node.append('circle')
      .attr("r", function(d) {
        if(source_nodes.includes (d.id)){
          return source_radius;
        } else {
          return radius;
        }
      })  
      .attr("fill", function(d) {
        if (source_nodes.includes (d.id)) {
          return 'url(#'+d.id.toString()+')';
        }
        else if (d.type == "predator" | d.type =="prey" | d.type =="competitor") {
          return color(gColor.indexOf(d.type));
        }
        else if (d.group%2==0) { return color(1);}
        else {return color(2);}
      })  ;
      
      new_node.on("click", d => {
          appendJSON(d);
      })
      .on('mouseover.fade', fade(0.1))
      .on('mouseout.fade', fade(1))
        .on('mouseover.tooltip', function(d) {
        tooltip.style("display", "inline-block")
        .style("opacity", .9)
        tooltip.html("<p style=\"font-size: 15px; color:"+ color(gColor.indexOf(d.type))+"; font-style: italic;\"><a href=\"https://eol.org/pages/"+d.id+"\" style=\"color: black; font-weight: bold; font-size: 15px\" target=\"_blank\">"+d.label+ "</a><br /><p>" + d.groupDesc + "</p><img src=\""+ d.icon+ "\" width=\"190\"><p>");
          });
      
      new_node.append('text')
        .attr('x', function(d) {
          if (source_nodes.includes(d.id)){
            return 32;
            
          } else {
            return 0; 
          }
        })
        .attr('y', function(d) {
          if(source_nodes.includes(d.id)){
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
        if(source_nodes.includes(d.id)) {
          return "left";
        } else {
          return "middle";
          
        }
      })
      .text(function(d) {return d.label;});
      
      existing_node = svg.selectAll('.existing_node')
      //UPDATE
      .data(existing_nodes)
      .enter().append('g')
      .attr('class', 'existing_node')
      .attr("transform",  d => `translate(${d.px},${d.py})`)
      .call(
        d3.drag()
        
        /*
        .subject(function() { 
          var t = d3.select(this);
          var tr = getTranslation(t.attr("transform"));
              
          return {
            x: t.attr("x") + tr[0],
            y: t.attr("y") + tr[1]
          };
        })
        .on("drag", function(d,i) {
          d3.select(this).attr("transform", function(d,i) {
            d.x = d3.event.x;
            d.y = d3.event.y;
            return "translate(" + [ d3.event.x, d3.event.y ] + ")";
          }
        );
     
          svg.selectAll('.link').data(existing_links).filter(l => (l.source === d))
            .transition().duration(1).attr("x1", d3.event.x).attr("y1", d3.event.y);
        })
        */
      );
      
      //APPEND IMAGE
      existing_node.append("svg:pattern")
      .attr("id", function(d) {return d.id.toString();})
        .attr("width", "100%")
        .attr("height", "100%")
        .attr("patternContentUnits", "objectBoundingBox")
      .attr("preserveAspectRatio", "xMidYMid slice")
      .attr("viewBox", "0 0 1 1")
        .append("svg:image")
        .attr("xlink:href", function(d) {return d.icon;})
        .attr("width", "1")
        .attr("height", "1")
      .attr("preserveAspectRatio", "xMidYMid slice");
      
      existing_node.append('circle')
      .attr("r", function(d) {
        if(source_nodes.includes (d.id)){
          return source_radius;
        } else {
          return radius;
        }
      })
      .attr("fill", function(d) {
        if (source_nodes.includes (d.id)) {
          return 'url(#'+d.id.toString()+')';
        }
        else if (d.type == "predator" | d.type =="prey" | d.type =="competitor") {
          return color(gColor.indexOf(d.type));
        }
        else if (d.group%2==0) { return color(1);}
        else {return color(2);}
      })
      .on('mouseover.fade', fade(0.1))
      .on('mouseout.fade', fade(1))
        .on('mouseover.tooltip', function(d) {
            
        tooltip.style("display", "inline-block")
        .style("opacity", .9)
        tooltip.html("<p style=\"font-size: 15px; color:"+ color(gColor.indexOf(d.type))+"; font-style: italic;\"><a href=\"https://eol.org/pages/"+d.id+"\" style=\"color: black; font-weight: bold; font-size: 15px\" target=\"_blank\">"+d.label+ "</a><br /><p>" + d.groupDesc + "</p><img src=\""+ d.icon+ "\" width=\"190\"><p>");
          });
      
      
      existing_node.append('text')
        .attr('x', function(d) {
          if (source_nodes.includes(d.id)){
            return 32;
            
          } else {
            return 0;
            
          }
        })
        .attr('y', function(d) {
          if(source_nodes.includes(d.id)){
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
        if(source_nodes.includes(d.id)) {
          return "left";
        } else {
          return "middle";
          
        }
      })
        .text(function(d) {return d.label;});
      
      
      existing_node.on("click", d => {appendJSON(d);})
      new_node.on("click", d => {appendJSON(d);})
      
      
      //ANIMATION 
      //existing nodes stay same & link follows the nodes
      svg.selectAll('.existing_node').data(existing_nodes)
      .transition().duration(5000).attr("transform",  d => `translate(${d.nx},${d.ny})`);
      svg.selectAll('.link').data(existing_links)
      .transition().duration(5000).attr("x1", function(d) { return d.source.nx; }).attr("y1", function(d) { return d.source.ny; }).attr("x2", function(d) { return d.target.nx; }).attr("y2", function(d) { return d.target.ny; })

      
      //new nodes and links appear after transition
      svg.selectAll('.new_node')
      .transition().duration(5000).delay(1000).attr("opacity", 1);
      svg.selectAll('.new_link').transition().duration(3000).delay(3000).attr("opacity", 1).on('end', function () {transition = false});


      simulation
        .nodes(graph.nodes)

        simulation.force("link")
          .links(graph.links);

        simulation.alpha(1).alphaTarget(0).restart();
      //new coordinate (n.x, n.y) -> past coordinate (p.x, p.y)
      updateCoordinates();  
    }

    function updateCoordinates() {
      graph.nodes.forEach(n=> {
        n.px = n.nx;
        n.py = n.ny;
      });
    }

    //new data
    function appendJSON(d) {
      var eol_id = d.id.toString();
      
      //http request to JSON data
      d3.json(dataUrl(eol_id), function(err, g) {
        if (err) { alert("No data found!"); throw err; }
        
        g.nodes.forEach(n => {
          var curNode = graph.nodes.find((m) => {
            return m.id == n.id;
          });

          if (curNode) {
            curNode.groupDesc = n.groupDesc;
          } else {
            graph.nodes.push(n);
            n.x = 0;
            n.y = 0;
            n.px = 0;
            n.py = 0;
            n.nx = 0;
            n.ny = 0;
            n.show = false;
            hiding_nodes.push(n);
          }
        });

        g.links.forEach(l => {
          if(!(linkIDList.includes(l.source.toString()+l.target.toString()))) {
            graph.links.push(l);
            l.show=false;       
            linkIDList.push(l.source.toString()+l.target.toString());
          }
        });
        
        simulation.nodes(graph.nodes);
        simulation.force("link").links(graph.links);
        setVisibilityOfNodesAndLinks(graph, d);
        updateGraph();
      }); 
    }

    function setVisibilityOfNodesAndLinks(graph, d) {
      var preyList = [];
      var predList = [];
      compList = [];

      curSource = addSourceNode(d);
        
      // set visibility of source/pred/prey nodes
      graph.nodes.forEach(node => {
        if (node.id==d.id){
          node.type ="source";
          node.show = true;
        } else if (isConnectedOneWay(d, node) && d.id != node.id){
          if (preyList.length < nLimit) {
            node.show = true;
            node.type = "prey";
            preyList.push(node);
          } else {
            node.show = false;
            node.type="none";
          }
        } else if (isConnectedOneWay(node, d) && d.id != node.id) {
          if (predList.length < nLimit) {
            node.show=true;
            node.type = "predator";
            predList.push(node);
          } else {
            node.show = false;
            node.type ="none"; 
          }
        } else {
          node.show=false;
          node.type="none";  
        }
      });
      
      //competitors
      graph.nodes.forEach(node => {
        preyList.forEach(n => {
          if (isConnectedOneWay(node, n) && node.type == "none"){
            if (compList.length < 10) {
              node.show = true;
              node.type = "competitor";
              compList.push([node, n] );
            } else {
              node.show = false;
              node.type = "none";
            }
          }
        });
      });
     
      // show links that belong to visible nodes
      graph.links.forEach(link => {
        if(link.source.show && link.target.show){
          link.show = true;
        } else {
          link.show = false;
        }
      });

      updatePositions();
    }

    function updatePositions() {
      //make a copy of an array
      var tmpPreyPos, tmpPredPos, tmpCompPos;
      
      tmpPreyPos = preyPos.slice();
      tmpPredPos = predPos.slice();
      
      graph.nodes.filter(n => n.show).forEach(node => {
        if (node.type == "source") {
          node.nx = sourcePos[0];
          node.ny = sourcePos[1];
        } else if (node.type == "predator") {
          var middle = tmpPredPos[Math.floor(tmpPredPos.length / 2)];
          var index = tmpPredPos.indexOf(middle);
          
          node.nx = middle[0];
          node.ny = middle[1];
        
          if (index > -1) {
            tmpPredPos.splice(index, 1);
          }
        } else if (node.type == "prey") {
          if (tmpPreyPos.length != 0) {
            var middle = tmpPreyPos[Math.floor(tmpPreyPos.length / 2)];
            var index = tmpPreyPos.indexOf(middle);

            node.nx = middle[0];
            node.ny = middle[1];
            
            if (index > -1) {
              tmpPreyPos.splice(index, 1);
            }
          }
        }
      });
      
      if (compList.length) {
        var extra = 5;
        var gap = (width - 100) / (compList.length + extra);
        compPos = [];
        
        for(var i = 0; i < compList.length + extra; i++) {
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

        $(compList).each((i, c) => {
          if(c[1].nx < width / 2) {
            c[0].nx = tmpCompPos[0];
            tmpCompPos.splice(0, 1);
          } else {
            var endIndex = tmpCompPos.length - 1;
            c[0].nx = tmpCompPos[endIndex];
            tmpCompPos.splice(endIndex, 1); 
          }

          c[0].ny = sourceY + (varHeight * varHeightCoefs[i % varHeightCoefs.length]);
        });

        compList.forEach(c => {
        });
      }
    }

    function addSourceNode (d) {
      //most recent source
      var index = source_nodes.length-1;
      //the first source node
      if (d.id == source_nodes[0].id) {
        //remove everything
        source_nodes.splice(d.id);
        //put the first source node (reset effect)
        source_nodes.push(d.id);
        d.type = "source";
      } 
      //already the source node
      else if (source_nodes.includes(d.id)) {
        d.type = "source";
      } 
      else {
        source_nodes.push(d.id);
        d.type = "source";
      }
      
      return d;
    }

    function fade(opacity) {
      return d => {
        if(!(transition)) {
            new_node.transition().duration(500).style('stroke-opacity', function (o) {
            const thisOpacity = isConnected(d, o) ? 1 : opacity;
            this.setAttribute('fill-opacity', thisOpacity);
            return thisOpacity;});
          
            existing_node.transition().duration(500).style('stroke-opacity', function (o) {
            const thisOpacity = isConnected(d, o) ? 1 : opacity;
            this.setAttribute('fill-opacity', thisOpacity);
            return thisOpacity;});

          
          new_link.style('opacity', o => (o.source === d || o.target === d ? 1 : opacity));

          existing_link.style('opacity', o => (o.source === d || o.target === d ? 1 : opacity));
         }};
    }

    function isConnected(a, b) {
        const linkedByIndex = {};
        graph.links.forEach(d => {
          linkedByIndex[`${d.source.index},${d.target.index}`] = 1;
        });
      return linkedByIndex[`${a.index},${b.index}`] || linkedByIndex[`${b.index},${a.index}`] || a.index === b.index;
    }

    function isConnectedOneWay(a, b) {
        const linkedByIndex = {};
        graph.links.forEach(d => {
          linkedByIndex[`${d.source.index},${d.target.index}`] = 1;
        });
      return linkedByIndex[`${a.index},${b.index}`];
    }

    function select(selector) {
      return d3.select('.js-trophic-web ' + selector);
    }

    function reset() {
      calculatePositions();
      s.transition().duration(100).call(zoom.transform, d3.zoomIdentity);
      setVisibilityOfNodesAndLinks(graph, graph.nodes[0]);
      updateGraph();
    }

    $(window).resize(reset);
  }

  var $container = $('.js-trophic-web .js-network-contain');

  if ($container.length) {
    createViz($container);
  }
});
