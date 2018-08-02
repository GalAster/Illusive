FourierPaintPointListToLines::usage = "";
PersonalCurveMake::usage = "";
PersonalCurveGet::usage = "";
FourierPlot::usage = "";
PersonalCurveLines::usage = "";
PersonalCurve::usage = "程序包的说明,这里抄一遍";
Begin["`PersonalCurve`"];
Needs["FourierSeries`"];
Package$Version = "V1.0";
Package$LastUpdate = "2018-01-06";
Options[FourierCoefficientPlot] = {
	Background -> Black,
	ImageSize -> 500,
	LastPointStyle -> {Purple, PointSize[0.02]},
	OutlineStyle -> {Yellow},
	InlineStyle -> {White},
	PlotStyle -> {},
	Last -> 2,
	Shift -> 0,
	PlotRange -> {{-5, 10}, {-4, 4}}
};
FourierCoefficientPlot[r_, n_, OptionsPattern[]] := Block[
	{st, lt, fun, par, tab, g, h},
	st = OptionValue[Shift];lt = OptionValue[Last];
	fun = Function[x, Accumulate@Prepend[
		ReIm@MapThread[#1 Exp[2 Pi I #2 x]&,
			{r, Range[Length@r]}
		], {0, 0}]];
	par = Function[t, r.Table[Sin[2 Pi j t], {j, Length@r}]];
	tab = Table[fun[j], {j, 0, 1, 1 / n}];
	g = Graphics[Flatten@{
		OptionValue[InlineStyle], MapThread[Circle[#1, Abs@#2]&, {Most@#, r}],
		Red, Point[Most@#],
		OptionValue[LastPointStyle], Point[Last@#],
		OptionValue[OutlineStyle], Line@tab[[All, -1]], Line@#,
		Dashed, Red, Line[{Last@#, {6 + st, #[[-1, 2]]}}]
	}, PlotRange -> OptionValue[PlotRange]]& /@ tab;
	h = Table[Plot[par[t - s], {s, 6 + st, 6 + st + lt},
		PlotStyle -> OptionValue[PlotStyle]], {t, 0, 1, 1 / n}];
	MapThread[Show[#1, #2,
		Background -> OptionValue[Background],
		ImageSize -> OptionValue[ImageSize]
	]&, {g, h}]];
Options[FourierPlot] = {Order -> 5};
FourierPlot[
	expr_, var_Symbol, nn_Integer : 1,
	ops : OptionsPattern[{FourierPlot, FourierCoefficientPlot}]
] := Block[
	{a, pics, x = var},
	a = Table[FourierSeries`NFourierSinCoefficient[expr, x, n, FourierParameters -> {1, 2Pi}], {n, OptionValue[Order]}];
	pics = If[nn == 1,
		Quiet@First@FourierCoefficientPlot[a, 1, ops],
		FourierCoefficientPlot[a, nn - 1, ops]
	]
];
FourierPaintPointListToLines[pointList_, neighborhoodSize_ : 6] := Block[
	{L = DeleteDuplicates[pointList], NF, \[Lambda], lineBag, counter, seenQ, sLB, nearest,
		nearest1, nextPoint, couldReverseQ, \[ScriptD], \[ScriptN], \[ScriptS]},
	NF = Nearest[L] ;
	\[Lambda] = Length[L];
	Monitor[
		lineBag = {};
		counter = 0;
		While[counter < \[Lambda],
			sLB = {RandomChoice[DeleteCases[L, _?seenQ]]};
			seenQ[sLB[[1]]] = True;
			counter++;
			couldReverseQ = True;
			While[(nearest = NF[Last[sLB], {Infinity, neighborhoodSize}];
			nearest1 = SortBy[DeleteCases[nearest, _?seenQ], 1.EuclideanDistance[Last[sLB], #]&];
			nearest1 =!= {} || couldReverseQ),
				If[nearest1 === {},
					sLB = Reverse[sLB]; couldReverseQ = False,
					nextPoint = If[Length[sLB] <= 3, nearest1[[1]],
						\[ScriptD] = 1.Normalize[(sLB[[-1]] - sLB[[-2]]) + 1 / 2 (sLB[[-2]] - sLB[[-3]])];
						\[ScriptN] = {-1, 1}Reverse[\[ScriptD]];
						\[ScriptS] = Sort[{Sqrt[(\[ScriptD].(# - sLB[[-1]]))^2 + 2 (\[ScriptN].(# - sLB[[-1]]))^2], # }& /@ nearest1];
						
						\[ScriptS][[1, 2]]];
					AppendTo[sLB, nextPoint];
					seenQ[nextPoint] = True;
					counter++ ]];
			AppendTo[lineBag, sLB]];
		Reverse[SortBy[Select[lineBag , Length[#] > 12&], Length]],
		Grid[
			{
				{Text[Style["正在锁定绘图点", Darker[Green, 0.66]]], ProgressIndicator[counter / \[Lambda]]},
				{Text[Style["已识别曲线数", Darker[Blue, 0.66]]], Length[lineBag] + 1}
			},
			Alignment -> Left, Dividers -> Center
		]
	]
];
FourierPaintComponentData[pointList_, nMax_, op_] := Module[
	{
		\[CurlyEpsilon] = 10^-3, \[Mu] = 2^14, M = 10000,
		s, scale, \[CapitalDelta], L , nds, sMax, if, \[ScriptX]\[ScriptY]Function, X, Y, XFT, YFT, type
	},
	scale = 1. Mean[Table[ Max[ fl /@ pointList] - Min[fl /@ pointList], {fl, {First, Last}}]];
	\[CapitalDelta] = EuclideanDistance[First[pointList], Last[pointList]];
	L = Which[op === "Closed", type = "Closed";
	If[First[pointList] === Last[pointList],
		pointList, Append[pointList, First[pointList]]],
		op === "Open", type = "Open";pointList,
		\[CapitalDelta] == 0., type = "Closed";  pointList,
		\[CapitalDelta] / scale < op, type = "Closed"; Append[pointList, First[pointList]],
		True, type = "Open"; Join[pointList, Rest[Reverse[pointList]]]];
	\[ScriptX]\[ScriptY]Function = BSplineFunction[L, SplineDegree -> 4];
	nds = NDSolve[{s'[t] == Sqrt[\[ScriptX]\[ScriptY]Function'[t].\[ScriptX]\[ScriptY]Function'[t]], s[0] == 0}, s,
		{t, 0, 1}, MaxSteps -> 10^5, PrecisionGoal -> 4];
	sMax = s[1] /. nds[[1]];
	if = Interpolation[Table[{s[\[Sigma]] /. nds[[1]], \[Sigma]}, {\[Sigma], 0, 1, 1 / M}]];
	X[t_Real] := BSplineFunction[L][Max[Min[1, if[(t + Pi) / (2Pi)sMax]] , 0]][[1]];
	Y[t_Real] := BSplineFunction[L][Max[Min[1, if[(t + Pi) / (2Pi)sMax]] , 0]][[2]];
	{XFT, YFT} = Fourier[Table[#[N @ t], {t, -Pi + \[CurlyEpsilon], Pi - \[CurlyEpsilon], (2Pi - 2\[CurlyEpsilon]) / \[Mu]}]]& /@ {X, Y};
	{type, 2Pi / Sqrt[\[Mu]] * ((Transpose[Table[{Re[#], Im[#]}&[Exp[I k Pi]  #[[k + 1]]], {k, 0, nMax}]]& /@ {XFT, YFT}))}
];
Options[FourierPaintComponent] = {"MaxOrder" -> 100, "OpenClose" -> 0.025};
FourierPaintComponent[pointLists_, OptionsPattern[]] :=
	Monitor[Table[
		FourierPaintComponentData[pointLists[[k]],
			If[Head[#] === List, #[[k]], #]&[ OptionValue["MaxOrder"]],
			If[Head[#] === List, #[[k]], #]&[ OptionValue["OpenClose"]]],
		{k, 1, Length[pointLists]}
	],
		Grid[{{
			Text[Style["正在计算傅里叶系数", Darker[Green, 0.66]]],
			ProgressIndicator[Refresh[k, UpdateInterval -> 1, TrackedSymbols -> {k}] / Length[pointLists]]
		}}
			, Alignment -> Left, Dividers -> Center]
	] /; Depth[pointLists] === 4;
FourierPaintLoss[data_] := Block[
	{k, x},
	Multicolumn[Table[
		ListLogLogPlot[Abs[Flatten[#[[2]], 1]],
			PlotRange -> All, Joined -> True,
			PlotLabel -> Style["curve" <> ToString@i, Bold]
		]&@data[[i]],
		{i, Length@data}]]
];
FourierPaintMakeFourierSeries[{"Closed" | "Open", {{cax_, sax_}, {cay_, say_}}}, t_, n_] := {
	Sum[If[k == 0, 1 / 2, 1]cax[[k + 1]] Cos[k t] + sax[[k + 1]] Sin[k t], {k, 0, Min[n, Length[cax]]}],
	Sum[If[k == 0, 1 / 2, 1]cay[[k + 1]] Cos[k t] + say[[k + 1]] Sin[k t], {k, 0, Min[n, Length[cay]]}]
};
FourierPaintSinAmplitudeForm[kt_, {cF_, sF_}] := With[{\[CurlyPhi] = FourierPaintPhase[cF, sF]}, Sqrt[cF^2 + sF^2] Sin[kt + \[CurlyPhi]]];
FourierPaintPhase[cF_, sF_] := With[
	{T = Sqrt[cF^2 + sF^2]},
	With[
		{g = Total[Abs[Table[cF Cos[x] + sF Sin[x] - T Sin[x + #1 ArcSin[cF / T] + #2], {x, 0, 1, 0.1}]]]&},
		If[g[1, 0] < g[-1, Pi], ArcSin[cF / T], Pi - ArcSin[cF / T]]
	]
];
FourierPaintSingleParametrization[fCs_, t_, n_] := UnitStep[
	Sign[Sqrt[Sin[t / 2]]]] * Sum[
	UnitStep[t - ((m - 1)4Pi - Pi)]UnitStep[(m - 1)4Pi + 3 Pi - t] * ({+ fCs[[m, 2, 1, 1, 1]] / 2
		+ Sum[FourierPaintSinAmplitudeForm[k t, {fCs[[m, 2, 1, 1, k + 1]], fCs[[m, 2, 1, 2, k + 1]]}],
		{k, Min[If[Head[n] === List, n[[m]], n], Length[fCs[[1 , 2, 1, 1]]]]}],
		+ fCs[[m, 2, 2, 1, 1]] / 2 + Sum[FourierPaintSinAmplitudeForm[k t, {fCs[[m, 2, 2, 1, k + 1]], fCs[[m, 2, 2, 2, k + 1]]}],
			{k, Min[If[Head[n] === List, n[[m]], n], Length[fCs[[1 , 2, 1, 1]]]]}]} ),
	{m, Length[fCs]}
];
FourierPaintPreviewMulticolumn[data_] := GraphicsGrid[
	Partition[With[
		{opts = Sequence[ PlotStyle -> Pink, Frame -> True, Axes -> False, FrameTicks -> None, PlotRange -> All, ImagePadding -> 12 ]},
		Table[Show[{ParametricPlot[Evaluate[ FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Closed", _}]], {t, -Pi, Pi}, opts],
			ParametricPlot[Evaluate[ FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Open", _}]], {t, -Pi, 0}, opts]},
			PlotLabel -> Style[n, Bold], ImageSize -> 240],
			{n, {1, 2, 3, 4, 5, 6, 8, 10, 20, 40, 50, 100}}]], 4],
	Spacings -> -10
];
FourierPaintPreviewManipulate[data_] := Manipulate[
	With[{opts = Sequence[PlotStyle -> Black, Frame -> True, Axes -> False, FrameTicks -> None, PlotRange -> All, ImagePadding -> 12]},
		Show[{
			ParametricPlot[Evaluate[ FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Closed", _}]], {t, -Pi, Pi}, opts],
			ParametricPlot[Evaluate[ FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Open", _}]], {t, -Pi, 0}, opts]
		}] // Quiet],
	{{n, 5, "展开阶数"}, 1, 50, 1, Appearance -> "Labeled"},
	TrackedSymbols :> True, SaveDefinitions -> True
];
FourierPaintPreviewExport[data_] := Block[
	{now, show, tab, e, t},
	now = AbsoluteTime[];
	show[n_] := Show[{
		ParametricPlot[Evaluate[FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Closed", _}]], {t, -Pi, Pi},
			PlotStyle -> Black, Frame -> True, Axes -> False, FrameTicks -> None,
			PlotRange -> All, ImagePadding -> 12
		],
		ParametricPlot[Evaluate[FourierPaintMakeFourierSeries[#, t, n]& /@ Cases[data, {"Open", _}]], {t, -Pi, 0},
			PlotStyle -> Black, Frame -> True, Axes -> False, FrameTicks -> None,
			PlotRange -> All, ImagePadding -> 12
		]
	}];
	tab = Quiet[Flatten[{#, Reverse@#}]&@Table[show[i], {i, 50}]];
	e = Export[DateString[
		DateObject[],
		{"Year", "Month", "Day", "-", "Hour24", "Minute", "Second"}
	] <> ".gif", tab, "AnimationRepetitions" -> Infinity];
	Echo[Quantity[Round[AbsoluteTime[] - now, 10^-4.], "Seconds"], "IO Time: "];
	e;
];
Options[FourierPaintFinalCurve] = {"order" -> 25, "dx" -> 10^-3};
FourierPaintFinalCurve[data_, t_, OptionsPattern[]] := Rationalize[
	FourierPaintSingleParametrization[data, t, OptionValue["order"]] ,
	OptionValue["dx"]
];
PersonalCurveImage[input_] := Graphics[
	{Hue[RandomReal[]], Line[#]}& /@ input,
	ImageSize -> {Automatic, 56},
	Background -> GrayLevel[0.97]
];
PersonalCurveDataQ[asc_?AssociationQ] := AllTrue[{"Icon", "Curves", "Order", "Time"}, KeyExistsQ[asc, #]&];
PersonalCurveDataQ[_] = False;
Format[PersonalCurveData[___], OutputForm] := "PersonalCurveData[<>]";
Format[PersonalCurveData[___], InputForm] := "PersonalCurveData[<>]";
PersonalCurveData /: MakeBoxes[obj : PersonalCurveData[asc_?PersonalCurveDataQ], form : (StandardForm | TraditionalForm)] := Module[
	{above, below},
	above = {
		{BoxForm`SummaryItem[{"Curves: ", asc["Curves"]}], SpanFromLeft},
		{BoxForm`SummaryItem[{"MaxOrder: ", asc["Order"]}], SpanFromLeft},
		{BoxForm`SummaryItem[{"TrainingTime: ", asc["Time"]}], SpanFromLeft}
	};
	below = {};
	BoxForm`ArrangeSummaryBox[
		"PersonalCurve", 
		obj, 
		asc["Icon"], 
		above, 
		below, 
		form,
		"Interpretable" -> Automatic
	]
];
Options[PersonalCurveMake] = {Order -> 100};
PersonalCurveMake[hLines_, OptionsPattern[]] := Block[
	{now, $icon, $curves, $order, $data, $time},
	now = AbsoluteTime[];
	$icon = PersonalCurveImage[hLines];
	$curves = Length[hLines];
	$order = OptionValue[Order];
	$data = FourierPaintComponent[
		hLines,
		"OpenClose" -> ConstantArray["Closed", Length[hLines]],
		"MaxOrder" -> OptionValue[Order]
	];
	$time = Quantity[Round[AbsoluteTime[] - now, 10^-4.], "Seconds"];
	PersonalCurveData[<|
		"Icon" -> $icon,
		"Curves" -> $curves,
		"Order" -> $order,
		"Time" -> $time,
		"Data" -> $data
	|>]
];
PersonalCurveData[ass_]["Loss"] := FourierPaintLoss@Lookup[ass, "Data"];
PersonalCurveData[ass_]["Grid"] := FourierPaintPreviewMulticolumn@Lookup[ass, "Data"];
PersonalCurveData[ass_]["Preview"] := FourierPaintPreviewManipulate@Lookup[ass, "Data"];
PersonalCurveData[ass_]["Export"] := FourierPaintPreviewExport@Lookup[ass, "Data"];
PersonalCurveData[ass_]["Curve"] := PersonalCurveGet[PersonalCurveData[ass]];
Options[PersonalCurveLines] = {PixelConstrained -> 10};
PersonalCurveLines[img_, OptionsPattern[]] := Block[
	{edge, lines, preview},
	edge = {#2, -#1}& @@@ Position[ImageData[EdgeDetect[img]], 1, {2}];
	lines = FourierPaintPointListToLines[edge, OptionValue[PixelConstrained]];
	preview = Graphics[{Hue[RandomReal[]], Line[#]}& /@ lines ];
	Echo[Length@lines, "识别曲线数: "];
	CellPrint[ExpressionCell[preview, "Output"]];
	Return[lines];
];
Options[PersonalCurveGet] = {Order -> 25, Rationalize -> 10^-2, Variables -> "t"};
PersonalCurveGet[PersonalCurveData[ass_], OptionsPattern[]] := Block[
	{cell, curve},
	cell = Cell[BoxData[
		RowBox[{"ListLinePlot", "[", RowBox[{RowBox[{"Table", "[", RowBox[{RowBox[{"Evaluate", "[",
			RowBox[{"N", "@", "curve"}], "]"}], ",", RowBox[{"{", RowBox[{ToString@OptionValue[Variables],
			",", "0", ",", RowBox[{"4", "Pi", "*", ToString@Lookup[ass, "Curves"]}], ",", "0.05"}], "}"}]}], "]"}],
			",", RowBox[{"AspectRatio", "->", "Automatic"}]}], "]"}]
	],
		"Input"
	];
	curve = FourierPaintFinalCurve[
		Lookup[ass, "Data"],
		ToExpression@OptionValue[Variables],
		"order" -> OptionValue[Order],
		"dx" -> OptionValue[Rationalize]
	];
	CellPrint[cell];
	Return[curve];
];
SetAttributes[
	{ },
	{Protected, ReadProtected}
];
End[]