<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>Unbound Statistics</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<style>
p{
font-weight: bolder;
}

.collapsible {
  color: white;
  padding: 0px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  cursor: pointer;
}

</style>
<script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/moment.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chart.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/hammerjs.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-zoom.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/chartjs-plugin-annotation.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/unbound_stats.sh/unboundstats.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/unbound_stats.sh/unboundstatstitle.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/unbound_stats.sh/unboundchpstats.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/unbound_stats.sh/unboundhistogramstats.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/unbound_stats.sh/unboundanswersstats.js"></script>


<script>
// Keep the real data in a seperate object called allData
// Put only that part of allData in the dataset to optimize zoom/pan performance
// Author: Evert van der Weit - 2018
function filterData(chartInstance) {
	var datasets = chartInstance.data.datasets;
	var originalDatasets = chartInstance.data.allData;
	var chartOptions = chartInstance.options.scales.xAxes[0];
	
	var startX = chartOptions.time.min;
	var endX = chartOptions.time.max;
	if(typeof originalDatasets === 'undefined' || originalDatasets === null) { return; }
	for(var i = 0; i < originalDatasets.length; i++) {
		var dataset = datasets[i];
		var originalData = originalDatasets[i];
		
		if (!originalData.length) break
		
		var s = startX;
		var e = endX;
		var sI = null;
		var eI = null;
		
		for (var j = 0; j < originalData.length; j++) {
			if ((sI==null) && originalData[j].x > s) {
				sI = j;
			}
			if ((eI==null) && originalData[j].x > e) {
				eI = j;
			}
		}
		if (sI==null) sI = 0;
		if (originalData[originalData.length - 1].x < s) eI = 0
			else if (eI==null) eI = originalData.length
		
		dataset.data = originalData.slice(sI, eI);
	}
}
var datafilterPlugin = {
	beforeUpdate: function(chartInstance) {
		filterData(chartInstance);
	}
}
</script>
<script>
var BarChartHistogram, BarChartAnswers;
var charttypehistogram, charttypeanswers;
var ShowLines=GetCookie("ShowLines");
var ShowFill=GetCookie("ShowFill");
Chart.defaults.global.defaultFontColor = "#CCC";
Chart.Tooltip.positioners.cursor = function(chartElements, coordinates) {
  return coordinates;
};
function Draw_Chart_NoData(txtchartname){
	document.getElementById(txtchartname).width="730";
	document.getElementById(txtchartname).height="300";
	document.getElementById(txtchartname).style.width="730px";
	document.getElementById(txtchartname).style.height="300px";
	var ctx = document.getElementById(txtchartname).getContext("2d");
	ctx.save();
	ctx.textAlign = 'center';
	ctx.textBaseline = 'middle';
	ctx.font = "normal normal bolder 48px Arial";
	ctx.fillStyle = 'white';
	ctx.fillText('No data to display', 365, 150);
	ctx.restore();
}
function Draw_Chart(txtchartname,txttitle,txtunity,txtunitx,numunitx,colourname){
	var objchartname=window["LineChart"+txtchartname];
	var txtdataname="Data"+txtchartname;
	var objdataname=window["Data"+txtchartname];
	if(typeof objdataname === 'undefined' || objdataname === null) { Draw_Chart_NoData(txtchartname); return; }
	if (objdataname.length == 0) { Draw_Chart_NoData(txtchartname); return; }
	factor=0;
	if (txtunitx=="hour"){
		factor=60*60*1000;
	}
	else if (txtunitx=="day"){
		factor=60*60*24*1000;
	}
	if (objchartname != undefined) objchartname.destroy();
	var ctx = document.getElementById(txtchartname).getContext("2d");
	var lineOptions = {
		segmentShowStroke : false,
		segmentStrokeColor : "#000",
		animationEasing : "easeOutQuart",
		animationSteps : 100,
		maintainAspectRatio: false,
		animateScale : true,
		legend: { display: false, position: "bottom", onClick: null },
		title: { display: true, text: txttitle },
		tooltips: {
			callbacks: {
					title: function (tooltipItem, data) { return (moment(tooltipItem[0].xLabel).format('YYYY-MM-DD HH:mm:ss')); },
					label: function (tooltipItem, data) { return data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].y.toString() + ' ' + txtunity;}
				},
				mode: 'point',
				position: 'cursor',
				intersect: true
		},
		scales: {
			xAxes: [{
				type: "time",
				gridLines: { display: true, color: "#282828" },
				ticks: {
					min: moment().subtract(numunitx, txtunitx+"s"),
					display: true
				},
				time: { unit: txtunitx, stepSize: 1 }
			}],
			yAxes: [{
				gridLines: { display: false, color: "#282828" },
				scaleLabel: { display: false, labelString: txttitle },
				ticks: {
					display: true,
					callback: function (value, index, values) {
						return round(value,2).toFixed(2) + ' ' + txtunity;
					}
				},
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: true,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(txtdataname,"y","min") - Math.sqrt(Math.pow(getLimit(txtdataname,"y","min"),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(txtdataname,"y","max") + getLimit(txtdataname,"y","max")*0.1,
					},
				},
				zoom: {
					enabled: true,
					mode: 'xy',
					rangeMin: {
						x: new Date().getTime() - (factor * numunitx),
						y: getLimit(txtdataname,"y","min") - Math.sqrt(Math.pow(getLimit(txtdataname,"y","min"),2))*0.1,
					},
					rangeMax: {
						x: new Date().getTime(),
						y: getLimit(txtdataname,"y","max") + getLimit(txtdataname,"y","max")*0.1,
					},
					speed: 0.1
				},
			},
		},
		annotation: {
			drawTime: 'afterDatasetsDraw',
			annotations: [{
				id: 'avgline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getAverage(objdataname),
				borderColor: colourname,
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Avg=" + round(getAverage(objdataname),2).toFixed(2)+txtunity,
				}
			},
			{
				id: 'maxline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(txtdataname,"y","max"),
				borderColor: colourname,
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Max=" + round(getLimit(txtdataname,"y","max"),2).toFixed(2)+txtunity,
				}
			},
			{
				id: 'minline',
				type: ShowLines,
				mode: 'horizontal',
				scaleID: 'y-axis-0',
				value: getLimit(txtdataname,"y","min"),
				borderColor: colourname,
				borderWidth: 1,
				borderDash: [5, 5],
				label: {
					backgroundColor: 'rgba(0,0,0,0.3)',
					fontFamily: "sans-serif",
					fontSize: 10,
					fontStyle: "bold",
					fontColor: "#fff",
					xPadding: 6,
					yPadding: 6,
					cornerRadius: 6,
					position: "center",
					enabled: true,
					xAdjust: 0,
					yAdjust: 0,
					content: "Min=" + round(getLimit(txtdataname,"y","min"),2).toFixed(2)+txtunity,
				}
			}]
		}
	};
	var lineDataset = {
		datasets: [{data: objdataname,
			label: txttitle,
			borderWidth: 1,
			pointRadius: 1,
			lineTension: 0,
			fill: ShowFill,
			backgroundColor: colourname,
			borderColor: colourname,
		}]
	};
	objchartname = new Chart(ctx, {
		type: 'line',
		plugins: [datafilterPlugin],
		options: lineOptions,
		data: lineDataset
	});
	window[txtchartname]=objchartname;
}
function getLimit(datasetname,axis,maxmin) {
	limit=0;
	eval("limit=Math."+maxmin+".apply(Math, "+datasetname+".map(function(o) { return o."+axis+";} ))");
	return limit;
}
function getAverage(datasetname) {
	var total = 0;
	for(var i = 0; i < datasetname.length; i++) {
		total += datasetname[i].y;
	}
	var avg = total / datasetname.length;
	return avg;
}
function round(value, decimals) {
	return Number(Math.round(value+'e'+decimals)+'e-'+decimals);
}
function ToggleLines() {
	if(ShowLines == ""){
		ShowLines = "line";
		SetCookie("ShowLines","line");
	}
	else {
		ShowLines = "";
		SetCookie("ShowLines","");
	}
	RedrawAllCharts();
}
function ToggleFill() {
	if(ShowFill == false){
		ShowFill = "origin";
		SetCookie("ShowFill","origin");
	}
	else {
		ShowFill = false;
		SetCookie("ShowFill",false);
	}
	RedrawAllCharts();
}
function RedrawAllCharts() {
	Draw_Chart("divLineChartCacheHitPercentDaily","Cache Hit Percent","%","hour",24,"#fc8500");
	Draw_Chart("divLineChartCacheHitPercentWeekly","Cache Hit Percent","%","day",7,"#42ecf5");
	Draw_Chart("divLineChartCacheHitPercentMonthly","Cache Hit Percent","%","day",30,"#ffffff");
}
function GetCookie(cookiename) {
	var s;
	if ((s = cookie.get("unbound_"+cookiename)) != null) {
		return cookie.get("unbound_"+cookiename);
	}
	else {
		return "";
	}
}
function SetCookie(cookiename,cookievalue) {
	cookie.set("unbound_"+cookiename, cookievalue, 31);
}

function GetCookieNew(cookiename,default_value) {
	var s;
	if ((s = cookie.get(cookiename)) != null) {
			if (s.match(/^([0-2])$/)) {
				E(cookiename).value = cookie.get(cookiename) * 1;
			}
	} else {
		E(cookiename).value = default_value;
	}
}

function SetCurrentPage(){
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function initial(){
	GetCookieNew("colourhistogram",0);
	GetCookieNew("charttypehistogram",1);
	GetCookieNew("colouranswers",0);
	GetCookieNew("charttypeanswers",2);
	SetCurrentPage();
	show_menu();
	SetUnboundStats();
	SetUnboundStatsTitle();
	RedrawAllCharts();
	Draw_Histogram_Chart();
	changeLayout(E('charttypehistogram'),"BarChartHistogram","charttypehistogram");
	Draw_Answers_Chart();
	changeLayout(E('charttypeanswers'),"BarChartAnswers","charttypeanswers");

	$("thead").click(function(){
		$(this).siblings().toggle("fast");
	})
	
	$(".default-collapsed").trigger("click");
}

function reload() {
	location.reload(true);
}

function applyRule() {
	var action_script_tmp = "start_unbound_stats.sh";
	document.form.action_script.value = action_script_tmp;
	var restart_time = document.form.action_wait.value*1;
	showLoading();
	document.form.submit();
}

function Draw_Histogram_Chart() {
	if(typeof barLabelsHistogram === 'undefined' || barLabelsHistogram === null || (Array.isArray(barLabelsHistogram) && barLabelsHistogram.length == 0)) { Draw_Chart_NoData("ChartHistogram"); return; }
	if(typeof barDataHistogram === 'undefined' || barDataHistogram === null || (Array.isArray(barDataHistogram) && barDataHistogram.length == 0)) { Draw_Chart_NoData("ChartHistogram"); return; }
	if (barLabelsHistogram.length == 0) { Draw_Chart_NoData("ChartHistogram"); return; }
	if (BarChartHistogram != undefined) BarChartHistogram.destroy();
	var ctx = document.getElementById("ChartHistogram").getContext("2d");
	var barOptionsHistogram = {
		segmentShowStroke : false,
		segmentStrokeColor : "#000",
		animationEasing : "easeOutQuart",
		animationSteps : 100,
		maintainAspectRatio: false,
		animateScale : true,
		legend: { display: false, position: "bottom", onClick: null },
		title: { display: false },
		tooltips: {
			callbacks: {
				title: function (tooltipItem, data) { return data.labels[tooltipItem[0].index]; },
				label: function (tooltipItem, data) { return comma(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]); },
			},
			mode: 'point',
			position: 'cursor',
			intersect: true
		},
		scales: {
			xAxes: [{
				display: showAxis(charttypehistogram,"x"),
				gridLines: { display: showGrid(charttypehistogram,"x"), color: "#282828" },
				ticks: { display: showAxis(charttypehistogram,"x"), beginAtZero: false }
			}],
			yAxes: [{
				display: showAxis(charttypehistogram,"y"),
				gridLines: { display: false, color: "#282828" },
				scaleLabel: { display: false, labelString: "Blocks" },
				ticks: { display: showAxis(charttypehistogram,"y"), beginAtZero: false }
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: true,
					mode: ZoomPanEnabled(charttypehistogram),
					rangeMin: {
						x: 0,
						y: 0
					},
					rangeMax: {
						x: ZoomPanMax(charttypehistogram,"x",barDataHistogram),
						y: ZoomPanMax(charttypehistogram,"y",barDataHistogram)
					},
				},
				zoom: {
					enabled: true,
					mode: ZoomPanEnabled(charttypehistogram),
					rangeMin: {
						x: 0,
						y: 0
					},
					rangeMax: {
						x: ZoomPanMax(charttypehistogram,"x",barDataHistogram),
						y: ZoomPanMax(charttypehistogram,"y",barDataHistogram)
					},
					speed: 0.1,
				}
			}
		}
	};
	var barDatasetHistogram = {
		labels: barLabelsHistogram,
		datasets: [{data: barDataHistogram,
			borderWidth: 1,
			backgroundColor: poolColors(barDataHistogram.length),
			borderColor: "#000000",
		}]
	};
	BarChartHistogram = new Chart(ctx, {
		type: getChartType(charttypehistogram),
		options: barOptionsHistogram,
		data: barDatasetHistogram
	});
	changeColour(E('colourhistogram'),BarChartHistogram,barDataHistogram,"colourhistogram")
}

function Draw_Answers_Chart() {
	if(typeof barLabelsAnswers === 'undefined' || barLabelsAnswers === null || (Array.isArray(barLabelsAnswers) && barLabelsAnswers.length == 0)) { Draw_Chart_NoData("ChartAnswers"); return; }
	if(typeof barDataAnswers === 'undefined' || barDataAnswers === null || (Array.isArray(barDataAnswers) && barDataAnswers.length == 0)) { Draw_Chart_NoData("ChartAnswers"); return; }
	if (barLabelsAnswers.length == 0) { Draw_Chart_NoData("ChartAnswers"); return; }
	if (BarChartAnswers != undefined) BarChartAnswers.destroy();
	var ctx = document.getElementById("ChartAnswers").getContext("2d");
	var barOptionsAnswers = {
		segmentShowStroke : false,
		segmentStrokeColor : "#000",
		animationEasing : "easeOutQuart",
		animationSteps : 100,
		maintainAspectRatio: false,
		animateScale : true,
		legend: { display: false, position: "bottom", onClick: null },
		title: { display: false },
		tooltips: {
			callbacks: {
				title: function (tooltipItem, data) { return data.labels[tooltipItem[0].index]; },
				label: function (tooltipItem, data) { return comma(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]); },
			},
			mode: 'point',
			position: 'cursor',
			intersect: true
		},
		scales: {
			xAxes: [{
				display: showAxis(charttypeanswers,"x"),
				gridLines: { display: showGrid(charttypeanswers,"x"), color: "#282828" },
				ticks: { display: showAxis(charttypeanswers,"x"), beginAtZero: false }
			}],
			yAxes: [{
				display: showAxis(charttypeanswers,"y"),
				gridLines: { display: false, color: "#282828" },
				scaleLabel: { display: false, labelString: "Blocks" },
				ticks: { display: showAxis(charttypeanswers,"y"), beginAtZero: false }
			}]
		},
		plugins: {
			zoom: {
				pan: {
					enabled: true,
					mode: ZoomPanEnabled(charttypeanswers),
					rangeMin: {
						x: 0,
						y: 0
					},
					rangeMax: {
						x: ZoomPanMax(charttypeanswers,"x",barDataAnswers),
						y: ZoomPanMax(charttypeanswers,"y",barDataAnswers)
					},
				},
				zoom: {
					enabled: true,
					mode: ZoomPanEnabled(charttypeanswers),
					rangeMin: {
						x: 0,
						y: 0
					},
					rangeMax: {
						x: ZoomPanMax(charttypeanswers,"x",barDataAnswers),
						y: ZoomPanMax(charttypeanswers,"y",barDataAnswers)
					},
					speed: 0.1,
				}
			}
		}
	};
	var barDatasetAnswers = {
		labels: barLabelsAnswers,
		datasets: [{data: barDataAnswers,
			borderWidth: 1,
			backgroundColor: poolColors(barDataAnswers.length),
			borderColor: "#000000",
		}]
	};
	BarChartAnswers = new Chart(ctx, {
		type: getChartType(charttypeanswers),
		options: barOptionsAnswers,
		data: barDatasetAnswers
	});
	changeColour(E('colouranswers'),BarChartAnswers,barDataAnswers,"colouranswers")
}

function changeColour(e,chartname,datasetname,cookiename) {
	colour = e.value * 1;
	if ( colour == 0 ) {
		chartname.config.data.datasets[0].backgroundColor = poolColors(datasetname.length);
	}
	else {
		chartname.config.data.datasets[0].backgroundColor = "rgba(2, 53, 135, 1)";
	}
	cookie.set(cookiename, colour, 31);
	chartname.update();
}

function changeLayout(e,chartname,cookiename) {
	layout = e.value * 1;
	if ( layout == 0 ) {
		if ( chartname == "BarChartHistogram" ) {
			charttypehistogram = "horizontalBar";
		}
		else if ( chartname == "BarChartAnswers" ) {
			charttypeanswers = "horizontalBar";
		}

	}
	else if ( layout == 1 ) {
		if ( chartname == "BarChartHistogram" ) {
			charttypehistogram = "bar";
		}
		else if ( chartname == "BarChartAnswers" ) {
			charttypeanswers = "bar";
		}

	}
	else if ( layout == 2 ) {
		if ( chartname == "BarChartHistogram" ) {
			charttypehistogram = "pie";
		}
		else if ( chartname == "BarChartAnswers" ) {
			charttypeanswers = "pie";
		}

	}
	cookie.set(cookiename, layout, 31);
	if ( chartname == "BarChartHistogram" ) {
		Draw_Histogram_Chart();
	}
	if ( chartname == "BarChartAnswers" ) {
		Draw_Answers_Chart();
	}

}

function showGrid(e,axis) {
	if (e == null) {
		return true;
	}
	else if (e == "pie") {
		return false;
	}
	else {
		return true;
	}
}
function showAxis(e,axis) {
	if (e == "bar" && axis == "x") {
		return false;
	}
	else {
		if (e == null) {
			return true;
		}
		else if (e == "pie") {
			return false;
		}
		else {
			return true;
		}
	}
}

function getRandomColor() {
	var r = Math.floor(Math.random() * 255);
	var g = Math.floor(Math.random() * 255);
	var b = Math.floor(Math.random() * 255);
	return "rgba(" + r + "," + g + "," + b + ", 1)";
}
function poolColors(a) {
	var pool = [];
	for(i = 0; i < a; i++) {
		pool.push(getRandomColor());
	}
	return pool;
}
function getChartType(e) {
	if (e == null) {
		return 'horizontalBar';
	}
	else {
		return e;
	}
}


function getSDev(datasetname){
	var avg = getAvg(datasetname);
	
	var squareDiffs = datasetname.map(function(value){
		var diff = value - avg;
		var sqrDiff = diff * diff;
		return sqrDiff;
	});
	
	var avgSquareDiff = getAvg(squareDiffs);
	var stdDev = Math.sqrt(avgSquareDiff);
	return stdDev;
}
function getMax(datasetname) {
	max = Math.max(...datasetname);
	return max + (max*0.1);
}
function getAvg(datasetname) {
	var sum, avg = 0;
	
	if (datasetname.length) {
		sum = datasetname.reduce(function(a, b) { return a*1 + b*1; });
		avg = sum / datasetname.length;
	}
	
	return avg;
}

function ZoomPanEnabled(charttype) {
	if (charttype == "bar") {
		return 'y';
	}
	else if (charttype == "horizontalBar") {
		return 'x';
	}
}
function ZoomPanMax(charttype, axis, datasetname) {
	if (axis == "x") {
		if (charttype == "bar") {
			return null;
		}
		else if (charttype == "horizontalBar") {
			return getMax(datasetname);
		}
	}
	else if (axis == "y") {
		if (charttype == "bar") {
			return getMax(datasetname);
		}
		else if (charttype == "horizontalBar") {
			return null;
		}
	}
}

</script>
</head>
<body onload="initial();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="about:blank" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="action_script" value="start_unbound_stats.sh">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_wait" value="5">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="SystemCmd" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div></td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tbody>
<tr bgcolor="#4D595D">
<td valign="top">
<div style="line-height:10px;">&nbsp;</div>
<div class="formfonttitle" id="unboundstatstitle">Unbound Statistics</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border:0px;">
<tr class="apply_gen" valign="top" height="35px">
<td style="background-color:rgb(77, 89, 93);border:0px;">
<input type="button" onclick="applyRule();" value="Update stats" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="RedrawAllCharts();" value="Reset Zoom" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ToggleLines();" value="Toggle Lines" class="button_gen" name="button">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<input type="button" onclick="ToggleFill();" value="Toggle Fill" class="button_gen" name="button">
</td>
</tr>
</table>

<div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible" id="last24">
<tr>
<td colspan="2">Cache Hit % Last 24 Hours (click to expand/collapse)</td>
</tr>
</thead>
<tr>
<td colspan="2" align="center" style="padding: 0px;">
<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChartCacheHitPercentDaily" height="300" /></div>
</td>
</tr>
</table>
<div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible default-collapsed" id="last7">
<tr>
<td colspan="2">Cache Hit % Last 7 days (click to expand/collapse)</td>
</tr>
</thead>
<tr>
<td colspan="2" align="center" style="padding: 0px;">
<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChartCacheHitPercentWeekly" height="300" /></div>
</td>
</tr>
</table><div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible default-collapsed" id="last30">
<tr>
<td colspan="2">Cache Hit % Last 30 days (click to expand/collapse)</td>
</tr>
</thead>
<tr>
<td colspan="2" align="center" style="padding: 0px;">
<div style="background-color:#2f3e44;border-radius:10px;width:730px;padding-left:5px;"><canvas id="divLineChartCacheHitPercentMonthly" height="300" /></div>
</td>
</tr>
</table>

<div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible" id="histogram">
<tr>
<td colspan="2">Performance Histogram (click to expand/collapse) - requires extended statistics enabled</td>
</tr>
</thead>
<tr>
<th width="40%">Style for charts</th>
<td>
<select style="width:100px" class="input_option" onchange="changeColour(this,BarChartHistogram,barDataHistogram,'colourhistogram')" id="colourhistogram">
<option value="0">Colour</option>
<option value="1">Plain</option>
</select>
</td>
</tr>
<tr>
<th width="40%">Layout for charts</th>
<td>
<select style="width:100px" class="input_option" onchange="changeLayout(this,'BarChartHistogram','charttypehistogram')" id="charttypehistogram">
<option value="0">Horizontal</option>
<option value="1">Vertical</option>
<option value="2">Pie</option>
</select>
</td>
</tr>
<tr>
<td colspan="2" style="padding: 2px;">
<div style="background-color:#2f3e44;border-radius:10px;width:735px;padding-left:5px;"><canvas id="ChartHistogram" height="360" /></div>
</td>
</tr>
</table>

<div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead class="collapsible" id="answers">
<tr>
<td colspan="2">DNS Answers to Queries (click to expand/collapse) - requires extended statistics enabled</td>
</tr>
</thead>
<tr>
<th width="40%">Style for charts</th>
<td>
<select style="width:100px" class="input_option" onchange="changeColour(this,BarChartAnswers,barDataAnswers,'colouranswers')" id="colouranswers">
<option value="0">Colour</option>
<option value="1">Plain</option>
</select>
</td>
</tr>
<tr>
<th width="40%">Layout for charts</th>
<td>
<select style="width:100px" class="input_option" onchange="changeLayout(this,'BarChartAnswers','charttypeanswers')" id="charttypeanswers">
<option value="0">Horizontal</option>
<option value="1">Vertical</option>
<option value="2">Pie</option>
</select>
</td>
</tr>
<tr>
<td colspan="2" style="padding: 2px;">
<div style="background-color:#2f3e44;border-radius:10px;width:735px;padding-left:5px;"><canvas id="ChartAnswers" height="360" /></div>
</td>
</tr>
</table>


<div style="line-height:10px;">&nbsp;</div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#4D595D" class="FormTable">
<tr>
<td colspan="2">Unbound Statistics Report</td>
</tr>
<tr>
<td style="padding: 0px;">
<textarea cols="75" rows="35" wrap="off" readonly="readonly" id="unboundstats" class="textarea_log_table" style="font-family:'Courier New', Courier, mono; font-size:11px;border: none;padding: 0px;">"Stats will show here"</textarea>
</td>
</tr>
</table>
<div style="line-height:10px;">&nbsp;</div>
</td>
</tr>
</tbody>
</table></td>
</tr>
</table>
</td>
</tr>
</table>
</form>
<div id="footer">
</div>
</body>
</html>
