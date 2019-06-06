//
//  CTVisualLabel.swift
//  CoreTextDemo
//
//  Created by guoyiyuan on 2019/2/22.
//  Copyright © 2019 guoyiyuan. All rights reserved.
//

import Foundation
import UIKit
import CoreText

private enum CTTextRunGlyphDrawMode: RawRepresentable {
	typealias RawValue = Int8
	
	case horizontalButMove(xCenter: Bool, yCenter: Bool)
	case verticalRotateAndMove(xCenter: Bool, yCenter: Bool)
	
	init?(rawValue: RawValue) {
		return nil
	}
	
	var rawValue: RawValue {
		switch self {
		case .horizontalButMove(let xCenter, let yCenter):
			switch (xCenter, yCenter) {
			case (true, true): return -1
			case (true, false): return -2
			case (false, true): return -3
			case (false, false): return -4
			}
		case .verticalRotateAndMove(let xCenter, let yCenter):
			switch (xCenter, yCenter) {
			case (true, true): return 1
			case (true, false): return 2
			case (false, true): return 3
			case (false, false): return 4
			}
		}
	}
}

private struct CTRunGlyphInfo {
	public fileprivate(set) var glyphRangeRun: NSRange = NSMakeRange(0, 0)
	public fileprivate(set) var drawMode: CTTextRunGlyphDrawMode = CTTextRunGlyphDrawMode.horizontalButMove(xCenter: false, yCenter: false)
}

private struct CTLineInfo {
	public fileprivate(set) var ascent: CGFloat = 0
	public fileprivate(set) var descent: CGFloat = 0
	public fileprivate(set) var leading: CGFloat = 0
	public fileprivate(set) var lineWidth: CGFloat = 0
	public fileprivate(set) var range: CFRange = CFRange()
	public fileprivate(set) var trailingWhitespaceWidth: CGFloat = 0
	public fileprivate(set) var firstGlyphPos: CGPoint = CGPoint.zero
	public fileprivate(set) var bounds: CGRect = CGRect.zero
}

class CTVisualLabel: UIView {
	public typealias CTTextCallback = () -> NSAttributedString
	
	private let defaultMaxContentSize: CGSize = CGSize(width: 0x100000, height: 0x100000)
	public var preferredMaxLayoutLimit: CGFloat = 0
	public var verticalAlignment: CTTextVerticalAlignment = .center
	public var contentInset: UIEdgeInsets = UIEdgeInsets.zero
	public var numberOfLines: Int = 0;
	public var vertical: Bool = true
	public var text: NSAttributedString! { didSet { self.setNeedsRedraw() }}
	public var textCb: CTTextCallback! { didSet { self.text = self.textCb() }}
	
	@inline(__always)
	private func setNeedsRedraw() {
		self.setNeedsDisplay()
		self.invalidateIntrinsicContentSize()
	}
	
	override func draw(_ rect: CGRect) {
		super.draw(rect)
		var ctxSize = bounds.size
		
		var rect = CGRect(origin: CGPoint.zero, size: ctxSize)
		rect = rect.inset(by: contentInset)
		//		print("rect: \(rect)")
		
		let ctPath = CGPath(rect: rect.applying(CGAffineTransform.init(scaleX: 1, y: -1)), transform: nil)
		
		let frameAttrs = NSMutableDictionary()
		frameAttrs[kCTFrameProgressionAttributeName] = CTFrameProgression.rightToLeft.rawValue
		
		let ctSetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
		let range = CFRange(location: 0, length: text.length)
		let ctFrame = CTFramesetterCreateFrame(ctSetter, range, ctPath, frameAttrs)
		let ctLines = CTFrameGetLines(ctFrame)
		let lineCount = CFArrayGetCount(ctLines)
		//		print("lineCount: \(lineCount)")
		var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
		CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, lineCount), &lineOrigins)
		var actualBoundingRect = CGRect.zero
		var actualBoundingSize = CGSize.zero
		var actualLinePosition = [CGPoint]()
		var actualLineRanges = [[[CTRunGlyphInfo]]]()
		for lineIndex in 0..<lineCount {
			let ctLine = unsafeBitCast(CFArrayGetValueAtIndex(ctLines, lineIndex), to: CTLine.self)
			let ctRuns = CTLineGetGlyphRuns(ctLine)
			if CFArrayGetCount(ctRuns) == 0 { continue }
			let ctLineOrigin = lineOrigins[lineIndex]
			print("ctLineOrigin: \(ctLineOrigin)")
			var position = CGPoint.zero
			position.x = rect.origin.x + ctLineOrigin.x
			position.y = rect.size.height + rect.origin.y - ctLineOrigin.y
			print("LinePosition: \(position)")
			if numberOfLines > 0, lineIndex > numberOfLines {
				break
			}
			
			var info = CTLineInfo.init()
			info.lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &info.ascent, &info.descent, &info.leading))
			info.range = CTLineGetStringRange(ctLine)
			info.trailingWhitespaceWidth = CGFloat(CTLineGetTrailingWhitespaceWidth(ctLine))
			let runs = CTLineGetGlyphRuns(ctLine)
			//			print("runs: \(CFArrayGetCount(runs))")
			if CFArrayGetCount(runs) > 0 {
				let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, 0), to: CTRun.self)
				CTRunGetPositions(run, CFRange(location: 0, length: 1), &info.firstGlyphPos);
			}
			print("firstGlyphPos: \(info.firstGlyphPos)")
			var bounds = CGRect.zero
			if vertical {
				bounds = CGRect(x: position.x - info.descent, y: position.y, width: info.ascent + info.descent, height: info.lineWidth)
				bounds.origin.y += info.firstGlyphPos.x
			} else {
				bounds = CGRect(x: position.x, y: position.y - info.descent, width: info.lineWidth, height: info.ascent + info.descent)
				bounds.origin.x += info.firstGlyphPos.x
			}
			info.bounds = bounds
			print("lineBounds: \(bounds)")
			let lineBounds = bounds
			
			if lineIndex == 0 {
				actualBoundingRect = lineBounds
			}
			actualBoundingRect = actualBoundingRect.union(lineBounds)
			actualBoundingSize = actualBoundingRect.size
			actualLinePosition.append(position)
			
			print("====================================")
		}
		
		var point = CGPoint.zero
		switch verticalAlignment {
		case .center:
			if vertical {
				point.x = -(bounds.size.width - actualBoundingSize.width) * 0.5
			} else {
				point.y = (bounds.size.height - actualBoundingSize.height) * 0.5
			}
		case .bottom:
			if vertical {
				point.x = -(bounds.size.width - actualBoundingSize.width)
			} else {
				point.y = bounds.size.height - actualBoundingSize.height
			}
			
		default: break
		}
		
		let context = UIGraphicsGetCurrentContext()
		guard let ctx = context else { return }
		ctx.saveGState()
		ctx.translateBy(x: point.x, y: point.y)
		ctx.translateBy(x: 0, y: bounds.size.height)
		ctx.scaleBy(x: 1, y: -1)
		ctx.setFillColor(UIColor.blue.cgColor)
		ctx.fill(rect)
		
		let verticalOffset = vertical ? bounds.size.width - rect.width : 0
		print("verticalOffset: \(verticalOffset)")
		let actualLineCount = (numberOfLines == 0 || (numberOfLines > lineCount)) ? lineCount : numberOfLines
		//		print("actualLineCount: \(actualLineCount)")
		for lineIndex in 0..<actualLineCount {
			let ctLine = unsafeBitCast(CFArrayGetValueAtIndex(ctLines, lineIndex) , to: CTLine.self)
			let posX = actualLinePosition[lineIndex].x + verticalOffset
			let posY = bounds.size.height - actualLinePosition[lineIndex].y
			let ctRuns = CTLineGetGlyphRuns(ctLine)
			for runIndex in 0..<CFArrayGetCount(ctRuns) {
				let ctRun = unsafeBitCast(CFArrayGetValueAtIndex(ctRuns, runIndex) , to: CTRun.self)
				ctx.textMatrix = CGAffineTransform.identity
				let runAttrs = CTRunGetAttributes(ctRun)
				
				let runFont = unsafeBitCast(CFDictionaryGetValue(runAttrs, unsafeBitCast(kCTFontAttributeName, to: UnsafeRawPointer.self)), to: CTFont.self)
				let glyphCount = CTRunGetGlyphCount(ctRun)
				if glyphCount <= 0 { continue }
				
				var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
				var glyphPositions = [CGPoint](repeating: CGPoint.zero, count: glyphCount)
				CTRunGetGlyphs(ctRun, CFRangeMake(0, 0), &glyphs)
				CTRunGetPositions(ctRun, CFRangeMake(0, 0), &glyphPositions)
				let attrs = runAttrs as! [NSAttributedString.Key:Any]
				let fillColor = (attrs[.foregroundColor] as! UIColor).cgColor
				
				ctx.saveGState()
				ctx.setFillColor(fillColor)
				ctx.setTextDrawingMode(.fill)

				var glyphAdvances = [CGSize](repeating: CGSize.zero, count: glyphCount)
				CTRunGetAdvances(ctRun, CFRangeMake(0, 0), &glyphAdvances)
				let ascent = CTFontGetAscent(runFont)
				let descent = CTFontGetDescent(runFont)
				
				for glyphIndex in 0..<glyphs.count {
					ctx.saveGState()
					ctx.textMatrix = CGAffineTransform.identity
					
					let ofs = (ascent - descent) * 0.5
					let w = glyphAdvances[glyphIndex].width * 0.5
					let x = actualLinePosition[lineIndex].x + verticalOffset + glyphPositions[glyphIndex].y
					let y = -actualLinePosition[lineIndex].y + bounds.size.height - glyphPositions[glyphIndex].x - (ofs + w)
					ctx.textPosition = CGPoint(x: x, y: y)
					print("textPosition: \(ctx.textPosition)")
					
					var zeroPoint = [CGPoint](repeating: CGPoint.zero, count: 1)
					let isColorGlyph = (CTFontGetSymbolicTraits(runFont).rawValue & CTFontSymbolicTraits.traitColorGlyphs.rawValue) != 0
					let copy_glyphs = [CGGlyph](repeating: glyphs[glyphIndex], count: 1)
					if isColorGlyph {
						CTFontDrawGlyphs(runFont, copy_glyphs, &zeroPoint, 1, ctx)
					} else {
						let cgFont = CTFontCopyGraphicsFont(runFont, nil)
						ctx.setFont(cgFont)
						ctx.setFontSize(CTFontGetSize(runFont))
						ctx.showGlyphs(copy_glyphs, at: zeroPoint)
					}
					ctx.restoreGState()
				}
			}
			
		}
	}
}
