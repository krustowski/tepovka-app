//
//  LineGraph.swift
//  Tepovka
//
//  Created by Kryštof Šara.
//  Copyright © 2020 Kryštof Šara. All rights reserved.
//

// https://medium.com/@tstenerson/lets-make-a-line-chart-in-swift-3-5e819e6c1a00

import UIKit

class LineChart: UIView {
    
    // Objekty kresleni
    let lineLayer = CAShapeLayer()
    let circlesLayer = CAShapeLayer()
    
    // Transformace vstupnich dat na X-Y souradnice
    var chartTransform: CGAffineTransform?
    
    // MARK: Parametricke promenne pouzitelne v InterfaceBuilder
    @IBInspectable var lineColor: UIColor = UIColor.green {
        didSet {
            lineLayer.strokeColor = lineColor.cgColor
        }
    }
    
    @IBInspectable var showPoints: Bool = true { // show the circles on each data point
        didSet {
            circlesLayer.isHidden = !showPoints
        }
    }
    
    @IBInspectable var circleColor: UIColor = UIColor.green {
        didSet {
            circlesLayer.fillColor = circleColor.cgColor
        }
    }
    
    @IBInspectable var lineWidth: CGFloat = 1
    @IBInspectable var circleSizeMultiplier: CGFloat = 3
    @IBInspectable var axisColor: UIColor = UIColor.white
    @IBInspectable var showInnerLines: Bool = true
    @IBInspectable var labelFontSize: CGFloat = 10
    
    // MARK: Promenne vlastni tridy
    var axisLineWidth: CGFloat = 1
    var deltaX: CGFloat = 10 // The change between each tick on the x axis
    var deltaY: CGFloat = 10 // and y axis
    var xMax: CGFloat = 100
    var yMax: CGFloat = 100
    var xMin: CGFloat = 0
    var yMin: CGFloat = 0
    var data: [CGPoint]?
    
    // Inicializace objektu
    override init(frame: CGRect) {
        super.init(frame: frame)
        combinedInit()
    }
    
    // Volano z InterfaceBuilderu
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        combinedInit()
    }
    
    func combinedInit() {
        layer.addSublayer(lineLayer)
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.strokeColor = lineColor.cgColor
        
        layer.addSublayer(circlesLayer)
        circlesLayer.fillColor = circleColor.cgColor
        
        layer.borderWidth = 1
        layer.borderColor = axisColor.cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        lineLayer.frame = bounds
        circlesLayer.frame = bounds
        
        if let d = data{
            setTransform(minX: xMin, maxX: xMax, minY: yMin, maxY: yMax)
            plot(d)
        }
    }
    
    // MARK: Methody
    func setAxisRange(forPoints points: [CGPoint]) {
        guard !points.isEmpty else { return }
        
        let xs = points.map() { $0.x }
        let ys = points.map() { $0.y }
        
        xMax = ceil(xs.max()! / deltaX) * deltaX
        yMax = ceil(ys.max()! / deltaY) * deltaY
        xMin = 0
        yMin = 0
        setTransform(minX: xMin, maxX: xMax, minY: yMin, maxY: yMax)
    }
    
    func setAxisRange(xMin: CGFloat, xMax: CGFloat, yMin: CGFloat, yMax: CGFloat) {
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
        
        setTransform(minX: xMin, maxX: xMax, minY: yMin, maxY: yMax)
    }
    
    // Afinni transforamce dat na souradnice
    func setTransform(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let xLabelSize = "\(Int(maxX))".size(withSystemFontSize: labelFontSize)
        let yLabelSize = "\(Int(maxY))".size(withSystemFontSize: labelFontSize)
        let xOffset = xLabelSize.height + 2
        let yOffset = yLabelSize.width + 5
        let xScale = (bounds.width - yOffset - xLabelSize.width/2 - 2)/(maxX - minX)
        let yScale = (bounds.height - xOffset - yLabelSize.height/2 - 2)/(maxY - minY)
        
        chartTransform = CGAffineTransform(a: xScale, b: 0, c: 0, d: -yScale, tx: yOffset, ty: bounds.height - xOffset)
        setNeedsDisplay()
    }
    
    // Kreslici funkce
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let t = chartTransform else { return }
        drawAxes(in: context, usingTransform: t)
    }
    
    func drawAxes(in context: CGContext, usingTransform t: CGAffineTransform) {
        context.saveGState()
        
        // Vytvor dve cesty, jednu pro tucne linky, druhou pro tenke
        let thickerLines = CGMutablePath()
        let thinnerLines = CGMutablePath()
        
        // Osy
        let xAxisPoints = [CGPoint(x: xMin, y: 0), CGPoint(x: xMax, y: 0)]
        let yAxisPoints = [CGPoint(x: 0, y: yMin), CGPoint(x: 0, y: yMax)]
        
        // Pridej linky i s transformaci
        thickerLines.addLines(between: xAxisPoints, transform: t)
        thickerLines.addLines(between: yAxisPoints, transform: t)
        
        // Kresleni bodu v mezich osy x
        for x in stride(from: xMin, through: xMax, by: deltaX) {
            
            // Taktovani bodu na kazde ose
            let tickPoints = showInnerLines ?
                [CGPoint(x: x, y: yMin).applying(t), CGPoint(x: x, y: yMax).applying(t)] :
                [CGPoint(x: x, y: 0).applying(t), CGPoint(x: x, y: 0).applying(t).adding(y: -5)]
            
            thinnerLines.addLines(between: tickPoints)
            
            // Kresleni taktovacich bodu
            if x != xMin {
                // Int pro zaokrouhleni, NSString ke kresleni
                let label = "\(Int(x))" as NSString
                let labelSize = "\(Int(x))".size(withSystemFontSize: labelFontSize)
                let labelDrawPoint = CGPoint(x: x, y: 0).applying(t)
                    .adding(x: -labelSize.width/2)
                    .adding(y: 1)
                
                label.draw(at: labelDrawPoint,
                           withAttributes:
                    [NSAttributedString.Key.font: UIFont.systemFont(ofSize: labelFontSize),
                     NSAttributedString.Key.foregroundColor: axisColor])
            }
        }
        
        // dtto pro osu y
        for y in stride(from: yMin, through: yMax, by: deltaY) {
            
            let tickPoints = showInnerLines ?
                [CGPoint(x: xMin, y: y).applying(t), CGPoint(x: xMax, y: y).applying(t)] :
                [CGPoint(x: 0, y: y).applying(t), CGPoint(x: 0, y: y).applying(t).adding(x: 5)]
            
            thinnerLines.addLines(between: tickPoints)
            
            if y != yMin {
                let label = "\(Int(y))" as NSString
                let labelSize = "\(Int(y))".size(withSystemFontSize: labelFontSize)
                let labelDrawPoint = CGPoint(x: 0, y: y).applying(t)
                    .adding(x: -labelSize.width - 1)
                    .adding(y: -labelSize.height/2)
                
                label.draw(at: labelDrawPoint,
                           withAttributes:
                    [NSAttributedString.Key.font: UIFont.systemFont(ofSize: labelFontSize),
                     NSAttributedString.Key.foregroundColor: axisColor])
            }
        }
        
        // Nastaveni parametru linky
        context.setStrokeColor(axisColor.cgColor)
        context.setLineWidth(axisLineWidth)
        context.addPath(thickerLines)
        context.strokePath()
        
        context.setStrokeColor(axisColor.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(axisLineWidth/2)
        context.addPath(thinnerLines)
        context.strokePath()
        
        // Obnoveni grafiky
        context.restoreGState()
    }
    
    // Hlavni vykreslovaci funkce
    func plot(_ points: [CGPoint]) {
        lineLayer.path = nil
        circlesLayer.path = nil
        data = nil
        
        guard !points.isEmpty else { return }
        
        self.data = points
        
        if self.chartTransform == nil {
            setAxisRange(forPoints: points)
        }
        
        let linePath = CGMutablePath()
        linePath.addLines(between: points, transform: chartTransform!)
        
        lineLayer.path = linePath
        
        if showPoints {
            circlesLayer.path = circles(atPoints: points, withTransform: chartTransform!)
        }
    }
    
    func circles(atPoints points: [CGPoint], withTransform t: CGAffineTransform) -> CGPath {
        let path = CGMutablePath()
        let radius = lineLayer.lineWidth * circleSizeMultiplier/2
        for i in points {
            let p = i.applying(t)
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            path.addEllipse(in: rect)
            
        }
        
        return path
    }
}

extension String {
    func size(withSystemFontSize pointSize: CGFloat) -> CGSize {
        return (self as NSString).size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: pointSize)])
    }
}

extension CGPoint {
    func adding(x: CGFloat) -> CGPoint { return CGPoint(x: self.x + x, y: self.y) }
    func adding(y: CGFloat) -> CGPoint { return CGPoint(x: self.x, y: self.y + y) }
}
