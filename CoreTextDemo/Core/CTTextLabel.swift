//
//  PolarisTextView.swift
//  CoreTextDemo
//
//  Created by guoyiyuan on 2018/11/27.
//  Copyright © 2018 guoyiyuan. All rights reserved.
//

import Foundation
import UIKit
import CoreText

public enum CTTextVerticalAlignment: UInt8 {
	case top
	case center
	case bottom
}

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

private func AboutCTLine(_ ctline: CTLine, vertical: Bool, at position: CGPoint) -> CTLineInfo {
	var info = CTLineInfo.init()
	info.lineWidth = CGFloat(CTLineGetTypographicBounds(ctline, &info.ascent, &info.descent, &info.leading))
	info.range = CTLineGetStringRange(ctline)
	info.trailingWhitespaceWidth = CGFloat(CTLineGetTrailingWhitespaceWidth(ctline))
	let runs = CTLineGetGlyphRuns(ctline)
	if CFArrayGetCount(runs) > 0 {
		let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, 0), to: CTRun.self)
		CTRunGetPositions(run, CFRange(location: 0, length: 1), &info.firstGlyphPos);
	}
	var bounds = CGRect.zero
	if vertical {
		bounds = CGRect(x: position.x /** - info.descent **/, y: position.y, width: info.ascent + info.descent, height: info.lineWidth)
		bounds.origin.y += info.firstGlyphPos.x
	} else {
		bounds = CGRect(x: position.x, y: position.y - info.descent, width: info.lineWidth, height: info.ascent + info.descent)
		bounds.origin.x += info.firstGlyphPos.x
	}
	info.bounds = bounds
	return info
}

private func AboutCTPath(_ rect: CGRect, path: CGPath?, exclusionPaths: [UIBezierPath]?) -> CGPath? {
	var transform = CGAffineTransform.init(scaleX: 1, y: -1)
	var calculateRect = CGRect(origin: .zero, size: rect.size)
	let calculatePath = CGPath(rect: calculateRect, transform: nil)
	var addedPath: CGMutablePath?
	switch (path, exclusionPaths) {
	case (.some, .none):
		guard path!.isRect(&calculateRect) else { return nil }
		return CGPath.init(rect: calculateRect, transform: &transform)
	case (.none, .some):
		addedPath = path!.mutableCopy()
	case (.some, .some):
		guard path!.isRect(&calculateRect) else { return nil }
		addedPath = CGPath(rect: rect, transform: nil).mutableCopy()
	default: return calculatePath
	}
	for temp in exclusionPaths! {
		addedPath!.addPath(temp.cgPath)
	}
	calculateRect = addedPath!.boundingBox
	return CGPath(rect: calculateRect, transform: &transform)
}

private func AboutCTVerticalFormMoveXCenterCharacterSet() -> NSCharacterSet {
	let c_set = NSMutableCharacterSet()
	c_set.addCharacters(in: NSMakeRange(0xFF0C, 1)) // ，
	c_set.addCharacters(in: NSMakeRange(0x3001, 1)) // 、
	c_set.addCharacters(in: NSMakeRange(0x3002, 1)) // 。
	c_set.addCharacters(in: NSMakeRange(0xFF1F, 1)) // ？
	c_set.addCharacters(in: NSMakeRange(0xFF01, 1)) // ！
	c_set.addCharacters(in: NSMakeRange(0xFF1A, 1)) // ：
	c_set.addCharacters(in: NSMakeRange(0x2026, 1)) // …
	c_set.addCharacters(in: NSMakeRange(0xFF1B, 1)) // ；
	return c_set
}

private func AboutCTVerticalFormMoveYCenterCharacterSet() -> NSCharacterSet {
	let c_set = NSMutableCharacterSet()
	c_set.addCharacters(in: NSMakeRange(0xFF0C, 1)) // ，
	c_set.addCharacters(in: NSMakeRange(0x3001, 1)) // 、
	c_set.addCharacters(in: NSMakeRange(0x3002, 1)) // 。

	return c_set
}

private func AboutCTVerticalFormRotateCharacterSet() -> NSCharacterSet {
	let c_set = NSMutableCharacterSet()
	c_set.addCharacters(in: NSMakeRange(0x2E80, 128)) // CJK Radicals Supplement
	c_set.addCharacters(in: NSMakeRange(0x3300, 256)) // CJK Compatibility
	c_set.addCharacters(in: NSMakeRange(0x4E00, 20941)) // CJK Unified Ideographs
	c_set.addCharacters(in: NSMakeRange(0xF900, 512)) // CJK Compatibility Ideographs
	c_set.addCharacters(in: NSMakeRange(0xFF0C, 1)) // ，
	c_set.addCharacters(in: NSMakeRange(0x3001, 1)) // 、
	c_set.addCharacters(in: NSMakeRange(0x3002, 1)) // 。
	c_set.addCharacters(in: NSMakeRange(0xFF1F, 1)) // ？
	c_set.addCharacters(in: NSMakeRange(0xFF01, 1)) // ！
	c_set.addCharacters(in: NSMakeRange(0xFF1A, 1)) // ：
	c_set.addCharacters(in: NSMakeRange(0xFF1B, 1)) // ；
	c_set.addCharacters(in: NSMakeRange(0xFF5C, 1)) // |
	c_set.addCharacters(in: NSMakeRange(0xFE41, 1)) // ﹁
	c_set.addCharacters(in: NSMakeRange(0xFE42, 1)) //  ﹂
	c_set.addCharacters(in: NSMakeRange(0xFE43, 1)) // ﹃
	c_set.addCharacters(in: NSMakeRange(0xFE44, 1)) //  ﹄
	return c_set
}

public class CTTextLabel: UIView {
	private let defaultMaxContentSize: CGSize = CGSize(width: 0x100000, height: 0x100000)
	
	public typealias CTTextCallback = () -> NSAttributedString
	
	public var vertical: Bool = true
	public var numberOfLines: Int = 0;
	public var contentInset: UIEdgeInsets = UIEdgeInsets.zero
	public var pathFillEvenOdd: Bool = true
	public var preferredMaxLayoutLimit: CGFloat = 0
	public var path: CGPath?
	public var exclusionPaths: [UIBezierPath]?
	public var verticalAlignment: CTTextVerticalAlignment = .center
	public var text: NSAttributedString! { didSet { self.setNeedsRedraw() }}
	public var textCb: CTTextCallback! { didSet { self.text = self.textCb() }}
	public var needsRedraw: Bool = false
	
	@inline(__always)
	private func setNeedsRedraw() {
		self.needsRedraw = true
		self.setNeedsDisplay()
		self.invalidateIntrinsicContentSize()
	}
	
	public override func draw(_ rect: CGRect) {
		guard needsRedraw == true else { return }
		var ctxSize = bounds.size
		if vertical {
			ctxSize.width = defaultMaxContentSize.width
			ctxSize.height = preferredMaxLayoutLimit > 0 ? preferredMaxLayoutLimit : bounds.size.height
		} else {
			ctxSize.height = defaultMaxContentSize.height
			ctxSize.width = preferredMaxLayoutLimit > 0 ? preferredMaxLayoutLimit : bounds.size.width
		}
		var rect = CGRect(origin: CGPoint.zero, size: ctxSize)
		rect = rect.inset(by: contentInset)
		
		let ctPath = CGPath(rect: rect.applying(CGAffineTransform.init(scaleX: 1, y: -1)), transform: nil)
		
		let frameAttrs = NSMutableDictionary()
		if vertical { frameAttrs[kCTFrameProgressionAttributeName] = CTFrameProgression.rightToLeft.rawValue }
		if pathFillEvenOdd { frameAttrs[kCTFramePathFillRuleAttributeName] = CTFramePathFillRule.evenOdd.rawValue  }
		else { frameAttrs[kCTFramePathFillRuleAttributeName] = CTFramePathFillRule.windingNumber.rawValue }
		let ctSetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
		let range = CFRange(location: 0, length: text.length)
		let ctFrame = CTFramesetterCreateFrame(ctSetter, range, ctPath, frameAttrs)
		let ctLines = CTFrameGetLines(ctFrame)
		let lineCount = CFArrayGetCount(ctLines)
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
			var position = CGPoint.zero
			position.x = rect.origin.x + ctLineOrigin.x
			position.y = rect.size.height + rect.origin.y - ctLineOrigin.y
			if numberOfLines > 0, lineIndex > numberOfLines {
				break
			}
			let lineBounds = AboutCTLine(ctLine, vertical: vertical, at: position).bounds
			if lineIndex == 0 {
				actualBoundingRect = lineBounds
			}
			actualBoundingRect = actualBoundingRect.union(lineBounds)
			actualBoundingSize = actualBoundingRect.size
			actualLinePosition.append(position)
		}
		
		if vertical {
			let rotateCharset = AboutCTVerticalFormRotateCharacterSet()
			let moveXCenterCharset = AboutCTVerticalFormMoveXCenterCharacterSet()
			let moveYCenterCharset = AboutCTVerticalFormMoveYCenterCharacterSet()
			
			for lineIndex in 0..<lineCount {
				let ctLine = unsafeBitCast(CFArrayGetValueAtIndex(ctLines, lineIndex) , to: CTLine.self)
				let ctRuns = CTLineGetGlyphRuns(ctLine)
				let runCount = CFArrayGetCount(ctRuns)
				var lineRunRanges = [[CTRunGlyphInfo]]()
				if runCount <= 0 { continue }
				for runIndex in 0..<runCount {
					let ctRun = unsafeBitCast(CFArrayGetValueAtIndex(ctRuns, runIndex) , to: CTRun.self)
					var runRanges = [CTRunGlyphInfo]()
					let glyphCount = CTRunGetGlyphCount(ctRun)
					if glyphCount <= 0 { continue }
					
					var runStrIndices = [CFIndex](repeating: 0, count: glyphCount+1)
					CTRunGetStringIndices(ctRun, CFRangeMake(0, 0), &runStrIndices)
					let runStrRange = CTRunGetStringRange(ctRun)
					runStrIndices[glyphCount] = runStrRange.location + runStrRange.length
					let runAttrs = CTRunGetAttributes(ctRun)
					let ctFont = unsafeBitCast(CFDictionaryGetValue(runAttrs, unsafeBitCast(kCTFontAttributeName, to: UnsafeRawPointer.self)), to: CTFont.self)
					let isColorGlyph = (CTFontGetSymbolicTraits(ctFont).rawValue & CTFontSymbolicTraits.traitColorGlyphs.rawValue) != 0
					
					var prevIndex = 0
					var prevMode = CTTextRunGlyphDrawMode.horizontalButMove(xCenter: false, yCenter: false)
					for glyphIndex in 0..<glyphCount {
						var glyphRotate = false
						var glyphMove = false
						var glyphMoveXCenter = false
						var glyphMoveYCenter = false
						let runStrLen = runStrIndices[glyphIndex + 1] - runStrIndices[glyphIndex]
						if isColorGlyph {
							glyphRotate = true
						} else if runStrLen == 1 {
							let character = (text.string as NSString).character(at: runStrIndices[glyphIndex])
							glyphMoveXCenter = moveXCenterCharset.characterIsMember(character)
							glyphMoveYCenter = moveYCenterCharset.characterIsMember(character)
							glyphMove = glyphMoveXCenter || glyphMoveYCenter
							glyphRotate = rotateCharset.characterIsMember(character)
						} else if runStrLen > 1 {
							let glyphStr = (text.string as NSString).substring(with: NSMakeRange(runStrIndices[glyphIndex], runStrLen))
							glyphMoveXCenter = (glyphStr.rangeOfCharacter(from: moveXCenterCharset as CharacterSet) != nil)
							glyphMoveYCenter = (glyphStr.rangeOfCharacter(from: moveYCenterCharset as CharacterSet) != nil)
							glyphMove = glyphMoveXCenter || glyphMoveYCenter
							glyphRotate = glyphStr.rangeOfCharacter(from: rotateCharset as CharacterSet) != nil
						}
						
						let mode = (glyphMove && glyphRotate) ? CTTextRunGlyphDrawMode.verticalRotateAndMove(xCenter: glyphMoveXCenter, yCenter: glyphMoveYCenter) : (glyphRotate ? CTTextRunGlyphDrawMode.verticalRotateAndMove(xCenter: false, yCenter: false) : (glyphMove ? CTTextRunGlyphDrawMode.horizontalButMove(xCenter: glyphMoveXCenter, yCenter: glyphMoveYCenter) : CTTextRunGlyphDrawMode.horizontalButMove(xCenter: false, yCenter: false)))
						if glyphIndex == 0 {
							prevMode = mode
						} else if (mode != prevMode) {
							var glyphRange = CTRunGlyphInfo()
							glyphRange.glyphRangeRun = NSMakeRange(prevIndex, glyphIndex - prevIndex)
							glyphRange.drawMode = prevMode
							runRanges.append(glyphRange)
							
							prevIndex = glyphIndex
							prevMode = mode
						}
					}
					
					if prevIndex < glyphCount {
						var glyphRange = CTRunGlyphInfo()
						glyphRange.glyphRangeRun = NSMakeRange(prevIndex, glyphCount - prevIndex)
						glyphRange.drawMode = prevMode
						runRanges.append(glyphRange)
					}
					lineRunRanges.append(runRanges)
				}
				actualLineRanges.append(lineRunRanges)
			}
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
//		ctx.setFillColor(UIColor.blue.cgColor)
//		ctx.fill(rect)
		
		let verticalOffset = vertical ? bounds.size.width - rect.width : 0
		let actualLineCount = numberOfLines > lineCount ? lineCount : numberOfLines
		for lineIndex in 0..<actualLineCount {
			let ctLine = unsafeBitCast(CFArrayGetValueAtIndex(ctLines, lineIndex) , to: CTLine.self)
			let posX = actualLinePosition[lineIndex].x + verticalOffset
			let posY = bounds.size.height - actualLinePosition[lineIndex].y
			let ctRuns = CTLineGetGlyphRuns(ctLine)
			for runIndex in 0..<CFArrayGetCount(ctRuns) {
				let ctRun = unsafeBitCast(CFArrayGetValueAtIndex(ctRuns, runIndex) , to: CTRun.self)
				ctx.textMatrix = CGAffineTransform.identity
				ctx.textPosition = CGPoint(x: posX, y: posY)
				
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
				
				if vertical {
					var runStrIndex = [CFIndex](repeating: 0, count: glyphCount + 1)
					CTRunGetStringIndices(ctRun, CFRangeMake(0, 0), &runStrIndex)
					let runStrRange = CTRunGetStringRange(ctRun)
					runStrIndex[glyphCount] = runStrRange.location + runStrRange.length
					var glyphAdvances = [CGSize](repeating: CGSize.zero, count: glyphCount)
					CTRunGetAdvances(ctRun, CFRangeMake(0, 0), &glyphAdvances)
					let ascent = CTFontGetAscent(runFont)
					let descent = CTFontGetDescent(runFont)
					var zeroPoint = [CGPoint](repeating: CGPoint.zero, count: 1)
					
					let lineRunRange = actualLineRanges[lineIndex]
					let runRange = lineRunRange[runIndex]
					
					for oneRange in runRange {
						let range = oneRange.glyphRangeRun
						let rangeMax = range.location + range.length
						let mode = oneRange.drawMode
						
						for glyphIndex in oneRange.glyphRangeRun.location..<rangeMax {
							ctx.saveGState()
							ctx.textMatrix = CGAffineTransform.identity
							
							var glyphPosition = CGPoint.zero
							if mode.rawValue > 0 {
								let ofs = (ascent - descent) * 0.5
								let w = glyphAdvances[glyphIndex].width * 0.5
								var x = actualLinePosition[lineIndex].x + verticalOffset + glyphPositions[glyphIndex].y + (ofs - w)
								var y = -actualLinePosition[lineIndex].y + bounds.size.height - glyphPositions[glyphIndex].x - (ofs + w)
								if case .verticalRotateAndMove(let xCenter, let yCenter) = mode {
									if xCenter == true {
										x += ofs
									}
									if yCenter == true {
										y += ofs
									}
								}
								glyphPosition = CGPoint(x: x, y: y)
							} else {
								let ctRunAttrs = CTRunGetAttributes(ctRun)
								let p_kern_key = Unmanaged.passUnretained(kCTKernAttributeName).toOpaque()
								let p_kern_val = CFDictionaryGetValue(ctRunAttrs, p_kern_key)
								let p_kern = Unmanaged<CFNumber>.fromOpaque(p_kern_val!).takeUnretainedValue()
								var kern: CGFloat = 0
								CFNumberGetValue(p_kern, .cgFloatType, &kern)
								ctx.rotate(by: CGFloat(-90 * Double.pi / 180))
								let ofs = (ascent - descent) * 0.5
								var x = actualLinePosition[lineIndex].y - bounds.size.height + glyphPositions[glyphIndex].x + kern * 0.5
								var y = actualLinePosition[lineIndex].x + verticalOffset + glyphPositions[glyphIndex].y - kern * 0.5
								if case .horizontalButMove(let xCenter, let yCenter) = mode {
									if xCenter == true {
										y += ofs
									}
									if yCenter == true {
										x += ofs
									}
								}
								glyphPosition = CGPoint(x: x, y: y)
							}
							
							switch contentMode {
							case .bottom:
								if case .horizontalButMove = mode {
									glyphPosition.x += (bounds.size.height - actualBoundingSize.height)
								} else {
									glyphPosition.y -= (bounds.size.height - actualBoundingSize.height)
								}
							case .center:
								if case .horizontalButMove = mode {
									glyphPosition.x += (bounds.size.height - actualBoundingSize.height) * 0.5
								} else {
									glyphPosition.y -= (bounds.size.height - actualBoundingSize.height) * 0.5
								}
							case .top:
								glyphPosition.y -= 0
							default: break
							}
							ctx.textPosition = glyphPosition
							
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
				} else {
					let isColorGlyph = (CTFontGetSymbolicTraits(runFont).rawValue & CTFontSymbolicTraits.traitColorGlyphs.rawValue) != 0
					let copy_glyphs = glyphs
					if isColorGlyph {
						CTFontDrawGlyphs(runFont, copy_glyphs, &glyphPositions, glyphCount, ctx)
					} else {
						let cgFont = CTFontCopyGraphicsFont(runFont, nil)
						ctx.setFont(cgFont)
						ctx.setFontSize(CTFontGetSize(runFont))
						ctx.showGlyphs(copy_glyphs, at: glyphPositions)
					}
				}
			}
		}
	}
}
