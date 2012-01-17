//
//  Edge.m
//  TikZiT
//  
//  Copyright 2010 Aleks Kissinger. All rights reserved.
//  
//  
//  This file is part of TikZiT.
//  
//  TikZiT is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  TikZiT is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with TikZiT.  If not, see <http://www.gnu.org/licenses/>.
//  

#import "Edge.h"
#import "util.h"

@implementation Edge

- (id)init {
	[super init];
	data = [[GraphElementData alloc] init];
	bend = 0;
	inAngle = 135;
	outAngle = 45;
	bendMode = EdgeBendModeBasic;
	weight = 0.4f;
	dirty = YES;
	source = nil;
	target = nil;
	edgeNode = nil;
	
	return self;
}

- (id)initWithSource:(Node*)s andTarget:(Node*)t {
	[self init];
	
	[self setSource:s];
	[self setTarget:t];
	edgeNode = nil;
	
	dirty = YES;
	
	return self;
}

- (BOOL)attachStyleFromTable:(NSArray*)styles {
	NSString *style_name = [data propertyForKey:@"style"];
	
	[self setStyle:nil];
	if (style_name == nil) return YES;
	
	for (EdgeStyle *s in styles) {
		if ([[s name] compare:style_name]==NSOrderedSame) {
			[self setStyle:s];
			return YES;
		}
	}
	
	// if we didn't find a style, fill in a default one
	style = [[EdgeStyle defaultEdgeStyleWithName:style_name] retain];
	return NO;
}

- (NSPoint) _findContactPointOn:(Node*)node at:(float)angle {
	return [node point];
}

- (void)updateControls {
	// check for external modification to the node locations
	if (src.x != [source point].x || src.y != [source point].y ||
		targ.x != [target point].x || targ.y != [target point].y)
	{
		dirty = YES;
	}
	
	if (dirty) {
		src = [source point];
		targ = [target point];
		
		float dx = (targ.x - src.x);
		float dy = (targ.y - src.y);
		
		float angleSrc = 0.0f;
		float angleTarg = 0.0f;
		
		if (bendMode == EdgeBendModeBasic) {
			float angle = good_atan(dx, dy);
			float bnd = (float)bend * (M_PI / 180.0f);
			angleSrc = angle - bnd;
			angleTarg = M_PI + angle + bnd;
		} else if (bendMode == EdgeBendModeInOut) {
			angleSrc = (float)outAngle * (M_PI / 180.0f);
			angleTarg = (float)inAngle * (M_PI / 180.0f);
		}

		head = [self _findContactPointOn:source at:angleSrc];
		tail = [self _findContactPointOn:target at:angleTarg];
		
		// give a default distance for self-loops
		float cdist = (dx==0.0f && dy==0.0f) ? weight : sqrt(dx*dx + dy*dy) * weight;
		
		cp1 = NSMakePoint(src.x + (cdist * cos(angleSrc)),
						  src.y + (cdist * sin(angleSrc)));
		
		cp2 = NSMakePoint(targ.x + (cdist * cos(angleTarg)),
						  targ.y + (cdist * sin(angleTarg)));
		
		mid.x = bezierInterpolate(0.5f, src.x, cp1.x, cp2.x, targ.x);
		mid.y = bezierInterpolate(0.5f, src.y, cp1.y, cp2.y, targ.y);
        
        dx = bezierInterpolate(0.6f, src.x, cp1.x, cp2.x, targ.x) - 
             bezierInterpolate(0.4f, src.x, cp1.x, cp2.x, targ.x);
        dy = bezierInterpolate(0.6f, src.y, cp1.y, cp2.y, targ.y) -
             bezierInterpolate(0.4f, src.y, cp1.y, cp2.y, targ.y);
        
        // normalise
        float len = sqrt(dx*dx+dy*dy);
        if (len != 0) {
            dx = (dx/len) * 0.1f;
            dy = (dy/len) * 0.1f;
        }
        
        midTan.x = mid.x + dx;
        midTan.y = mid.y + dy;
	}
	dirty = NO;
}

- (void)convertBendToAngles {
	float dx = (targ.x - src.x);
	float dy = (targ.y - src.y);
	float angle = good_atan(dx, dy);
	float bnd = (float)bend * (M_PI / 180.0f);
	
	[self setOutAngle:round((angle - bnd) * (180.0f/M_PI))];
	[self setInAngle:round((M_PI + angle + bnd) * (180.0f/M_PI))];
	dirty = YES;
}

- (void)convertAnglesToBend {
	float dx = (targ.x - src.x);
	float dy = (targ.y - src.y);
	int angle = round((180.0f/M_PI) * good_atan(dx, dy));
	
	// compute bend1 and bend2 to match inAngle and outAngle, resp.
	int bend1, bend2;
	
	bend1 = outAngle - angle;
	bend2 = angle - inAngle;
	
	[self setBend:(bend1 + bend2) / 2];
}

- (BOOL)isSelfLoop {
	return (source == target);
}

- (BOOL)isStraight {
	return (bendMode == EdgeBendModeBasic && bend == 0);
}

- (NSPoint)mid {
	[self updateControls];
	return mid;
}

- (NSPoint)midTan {
	[self updateControls];
	return midTan;
}

- (NSPoint)leftNormal {
	[self updateControls];
	return NSMakePoint(mid.x + (mid.y - midTan.y), mid.y - (mid.x - midTan.x));
}

- (NSPoint)rightNormal {
    [self updateControls];
	return NSMakePoint(mid.x - (mid.y - midTan.y), mid.y + (mid.x - midTan.x));
}

- (NSPoint)cp1 {
	[self updateControls];
	return cp1;
}

- (NSPoint)cp2 {
	[self updateControls];
	return cp2;
}

- (int)inAngle {return inAngle;}
- (void)setInAngle:(int)a {
	inAngle = normaliseAngleDeg (a);
	dirty = YES;
}

- (int)outAngle {return outAngle;}
- (void)setOutAngle:(int)a {
	outAngle = normaliseAngleDeg (a);
	dirty = YES;
}

- (EdgeBendMode)bendMode {return bendMode;}
- (void)setBendMode:(EdgeBendMode)mode {
	bendMode = mode;
	dirty = YES;
}

- (int)bend {return bend;}
- (void)setBend:(int)b {
	bend = normaliseAngleDeg (b);
	dirty = YES;
}

- (float)weight {return weight;}
- (void)setWeight:(float)w {
//	if (source == target) weight = 1.0f;
//	else weight = w;
	weight = w;
	dirty = YES;
}

- (EdgeStyle*)style {return style;}
- (void)setStyle:(EdgeStyle*)s {
	if (style != s) {
		[style release];
		style = [s retain];
	}
}

- (Node*)source {return source;}
- (void)setSource:(Node *)s {
	if (source != s) {
		[source release];
		source = [s retain];
		
		if (source==target) {
			bendMode = EdgeBendModeInOut;
			weight = 1.0f;
		}
		
		dirty = YES;
	}
}

- (Node*)target {return target;}
- (void)setTarget:(Node *)t {
	if (target != t) {
		[target release];
		target = [t retain];
		
		if (source==target) {
			bendMode = EdgeBendModeInOut;
			weight = 1.0f;
		}
		
		dirty = YES;
	}
}


// edgeNode and hasEdgeNode use a bit of key-value observing to help the mac GUI keep up

- (Node*)edgeNode {return edgeNode;}
- (void)setEdgeNode:(Node *)n {
#if defined (__APPLE__)
    [self willChangeValueForKey:@"edgeNode"];
    [self willChangeValueForKey:@"hasEdgeNode"];
#endif
	if (edgeNode != n) {
        hasEdgeNode = (n != nil);
		[edgeNode release];
		edgeNode = [n retain];
		// don't set dirty bit, because control points don't need update
	}
#if defined (__APPLE__)
    [self didChangeValueForKey:@"edgeNode"];
    [self didChangeValueForKey:@"hasEdgeNode"];
#endif
}

- (BOOL)hasEdgeNode { return hasEdgeNode; }
- (void)setHasEdgeNode:(BOOL)b {
#if defined (__APPLE__)
    [self willChangeValueForKey:@"edgeNode"];
    [self willChangeValueForKey:@"hasEdgeNode"];
#endif
    hasEdgeNode = b;
    if (hasEdgeNode && edgeNode == nil) {
        edgeNode = [[Node alloc] init];
    }
#if defined (__APPLE__)
    [self didChangeValueForKey:@"edgeNode"];
    [self didChangeValueForKey:@"hasEdgeNode"];
#endif
}

- (GraphElementData*)data {return data;}
- (void)setData:(GraphElementData*)dt {
	if (data != dt) {
		[data release];
		data = [dt copy];
	}
}

- (void)updateData {
	// unset everything to avoid redundant defs
	[data unsetAtom:@"loop"];
	[data unsetProperty:@"in"];
	[data unsetProperty:@"out"];
	[data unsetAtom:@"bend left"];
	[data unsetAtom:@"bend right"];
	[data unsetProperty:@"bend left"];
	[data unsetProperty:@"bend right"];
	[data unsetProperty:@"looseness"];
    
    if (style == nil) {
        [data unsetProperty:@"style"];
    } else {
        [data setProperty:[style name] forKey:@"style"];
    }
	
	if (bendMode == EdgeBendModeBasic && bend != 0) {
		NSString *bendkey = @"bend right";
		int b = [self bend];
		if (b < 0) {
			bendkey = @"bend left";
			b = -b;
		}
		
		if (b == 30) {
			[data setAtom:bendkey];
		} else {
			[data setProperty:[NSString stringWithFormat:@"%d",b] forKey:bendkey];
		}
		
	} else if (bendMode == EdgeBendModeInOut) {
		[data setProperty:[NSString stringWithFormat:@"%d",inAngle]
				   forKey:@"in"];
		[data setProperty:[NSString stringWithFormat:@"%d",outAngle]
				   forKey:@"out"];
	}
	
	// loop needs to come after in/out
	if (source == target) [data setAtom:@"loop"];
	
	if (!(
		  ([self isSelfLoop]) ||
		  (source!=target && weight == 0.4f)
	   ))
	{
		[data setProperty:[NSString stringWithFormat:@"%.2f",weight*2.5f]
				   forKey:@"looseness"];
	}
}

- (void)setAttributesFromData {
	bendMode = EdgeBendModeBasic;
	
	if ([data isAtomSet:@"bend left"]) {
		[self setBend:-30];
	} else if ([data isAtomSet:@"bend right"]) {
		[self setBend:30];
	} else if ([data propertyForKey:@"bend left"] != nil) {
		NSString *bnd = [data propertyForKey:@"bend left"];
		[self setBend:-[bnd intValue]];
	} else if ([data propertyForKey:@"bend right"] != nil) {
		NSString *bnd = [data propertyForKey:@"bend right"];
		[self setBend:[bnd intValue]];
	} else {
		[self setBend:0];
		
		if ([data propertyForKey:@"in"] != nil && [data propertyForKey:@"out"] != nil) {
			bendMode = EdgeBendModeInOut;
			[self setInAngle:[[data propertyForKey:@"in"] intValue]];
			[self setOutAngle:[[data propertyForKey:@"out"] intValue]];
		}
	}
	
	if ([data propertyForKey:@"looseness"] != nil) {
		weight = [[data propertyForKey:@"looseness"] floatValue] / 2.5f;
	} else {
		weight = ([self isSelfLoop]) ? 1.0f : 0.4f;
	}
}

- (void)setPropertiesFromEdge:(Edge*)e {
    Node *en = [[e edgeNode] copy];
	[self setEdgeNode:en];
    [en release];
    
    GraphElementData *d = [[e data] copy];
	[self setData:d];
    [d release];
    
    [self setStyle:[e style]];
	[self setBend:[e bend]];
	[self setInAngle:[e inAngle]];
	[self setOutAngle:[e outAngle]];
	[self setBendMode:[e bendMode]];
	[self setWeight:[e weight]];
    
	dirty = YES; // cached data will be recomputed lazily, rather than copied
}

- (NSRect)boundingRect {
	[self updateControls];
	return NSRectAround4Points(src, targ, cp1, cp2);
}

- (void) adjustWeight:(float)handle_dist withCourseness:(float)wcourseness {
    float base_dist = NSDistanceBetweenPoints (src, targ);
    if (base_dist == 0.0f) {
        base_dist = 1.0f;
    }

    [self setWeight:roundToNearest(wcourseness, handle_dist / base_dist)];
}

- (float) angleOf:(NSPoint)point relativeTo:(NSPoint)base {
    float dx = point.x - base.x;
    float dy = point.y - base.y;
    return radiansToDegrees (good_atan(dx, dy));
}

- (void) moveCp1To:(NSPoint)point withWeightCourseness:(float)wc andBendCourseness:(int)bc forceLinkControlPoints:(BOOL)link {
    [self updateControls];
    [self adjustWeight:NSDistanceBetweenPoints (point, src) withCourseness:wc];

    float control_angle = [self angleOf:point relativeTo:src];
    if (bendMode == EdgeBendModeBasic) {
        float base_angle = [self angleOf:targ relativeTo:src];
        int b = (int)roundToNearest (bc, base_angle - control_angle);
        [self setBend:b];
    } else {
        int angle = (int)roundToNearest (bc, control_angle);
        if (link) {
            [self setInAngle:(inAngle + angle - outAngle)];
        }
        [self setOutAngle:angle];
    }
}

- (void) moveCp1To:(NSPoint)point {
	[self moveCp1To:point withWeightCourseness:0.0f andBendCourseness:0 forceLinkControlPoints:NO];
}

- (void) moveCp2To:(NSPoint)point withWeightCourseness:(float)wc andBendCourseness:(int)bc forceLinkControlPoints:(BOOL)link {
    [self updateControls];

    if (![self isSelfLoop]) {
        [self adjustWeight:NSDistanceBetweenPoints (point, targ) withCourseness:wc];
    }

    float control_angle = [self angleOf:point relativeTo:targ];
    if (bendMode == EdgeBendModeBasic) {
        float base_angle = [self angleOf:src relativeTo:targ];
        int b = (int)roundToNearest (bc, control_angle - base_angle);
        [self setBend:b];
    } else {
        int angle = (int)roundToNearest (bc, control_angle);
        if (link) {
            [self setOutAngle:(outAngle + angle - inAngle)];
        }
        [self setInAngle: angle];
    }
}

- (void) moveCp2To:(NSPoint)point {
	[self moveCp2To:point withWeightCourseness:0.0f andBendCourseness:0 forceLinkControlPoints:NO];
}

- (void)reverse {
    Node *n;
    float f;
    
    n = source;
    source = target;
    target = n;
    
    f = inAngle;
    inAngle = outAngle;
    outAngle = f;
    
    [self setBend:-bend];
    
    dirty = YES;
}

- (void)dealloc {
	[self setSource:nil];
	[self setTarget:nil];
	[self setData:nil];
	[super dealloc];
}

- (id)copy {
	Edge *cp = [[Edge alloc] init];
	[cp setSource:[self source]];
	[cp setTarget:[self target]];
	[cp setPropertiesFromEdge:self];
	return cp;
}

+ (Edge*)edge {
	return [[[Edge alloc] init] autorelease];
}

+ (Edge*)edgeWithSource:(Node*)s andTarget:(Node*)t {
	return [[[Edge alloc] initWithSource:s andTarget:t] autorelease];
}

@end

// vi:ft=objc:ts=4:noet:sts=4:sw=4