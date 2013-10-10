package;
 
/**
 *
 * Sample: Fixed Dragging
 * Author: Luca Deltodesco
 *
 * Demonstrating how one might perform a Nape simulation
 * that uses a fixed-time step for better reproducibility.
 * Also demonstrate how to use a PivotJoint for dragging
 * of Nape physics objects.
 *
 */
 
import flash.Lib;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
 
import nape.constraint.PivotJoint;
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Circle;
import nape.shape.Polygon;
import nape.space.Space;
import nape.util.BitmapDebug;
import nape.util.Debug;
 
class PhysicsTest{
 
    public var space:Space;
    var handJoint:PivotJoint;
 
    var prevTimeMS:Int;
    var simulationTime:Float;

    var w:Float;
    var h:Float;
 
    public function new(w:Float, h:Float) {
    	this.w =w;
    	this.h =h;
        initialise();
    }
 
    function initialise():Void {
        // Create a new simulation Space.
        //
        //   Default gravity is (0, 0)
        space = new Space();
 
        // Create a new BitmapDebug screen matching stage dimensions and
        // background colour.
        //
        //   The Debug object itself is not a DisplayObject, we add its
        //   display property to the display list.
        //
        //   We additionally set the flag enabling drawing of constraints
        //   when rendering a Space object to true.
 
        setUp();
    }
 
    function setUp():Void {

        // Create a static border around stage.
        var border = new Body(BodyType.STATIC);
        border.shapes.add(new Polygon(Polygon.rect(0, 0, w, -1)));
        border.shapes.add(new Polygon(Polygon.rect(0, h, w, 1)));
        border.shapes.add(new Polygon(Polygon.rect(0, 0, -1, h)));
        border.shapes.add(new Polygon(Polygon.rect(w, 0, 1, h)));
        border.space = space;
 
        // Generate some random objects!
        for (i in 0...100) {
            var body = new Body();
        
            var r:Float = Math.random()*20+10;
            // Add random one of either a Circle, Box or Pentagon.
            if (Math.random() < 0.33) {
                body.shapes.add(new Circle(r));
            }
            /*else if (Math.random() < 0.5) {
                body.shapes.add(new Polygon(Polygon.box(40, 40)));
            }*/
            else {                
                body.shapes.add(new Polygon(Polygon.regular(r, r, Math.round(Math.random()*4 + 3) )));
            }
 
            // Set to random position on stage and add to Space.
            body.position.setxy(Math.random() * w, Math.random() * h);
            body.space = space;
        }
 
        // Set up a PivotJoint constraint for dragging objects.
        //
        //   A PivotJoint constraint has as parameters a pair
        //   of anchor points defined in the local coordinate
        //   system of the respective Bodys which it strives
        //   to lock together, permitting the Bodys to rotate
        //   relative to eachother.
        //
        //   We create a PivotJoint with the first body given
        //   as 'space.world' which is a pre-defined static
        //   body in the Space having no shapes or velocities.
        //   Perfect for dragging objects or pinning things
        //   to the stage.
        //
        //   We do not yet set the second body as this is done
        //   in the mouseDownHandler, so we add to the Space
        //   but set it as inactive.
        handJoint = new PivotJoint(space.world, null, Vec2.weak(), Vec2.weak());
        handJoint.space = space;
        handJoint.active = false;
 
        // We also define this joint to be 'elastic' by setting
        // its 'stiff' property to false.
        //
        //   We could further configure elastic behaviour of this
        //   constraint through the 'frequency' and 'damping'
        //   properties.
        handJoint.stiff = false;
    }
 
    public function step(dt:Float)
    {
    	// If the hand joint is active, then set its first anchor to be
    	// at the mouse coordinates so that we drag bodies that have
    	// have been set as the hand joint's body2.
    	if (handJoint.active) {
    	    handJoint.anchor1.setxy(mouseX, mouseY);
    	}

    	space.step(dt);
    }

    var mouseX:Float;
    var mouseY:Float;
    public function mouseMoveHandler(ev:MouseEvent){
    	mouseX = ev.stageX;mouseY = ev.stageY;
    }
 
    public function mouseDownHandler(ev:MouseEvent):Void {
    	mouseX = ev.stageX;mouseY = ev.stageY;
        // Allocate a Vec2 from object pool.
        var mousePoint = Vec2.get(mouseX, mouseY);
 
        // Determine the set of Body's which are intersecting mouse point.
        // And search for any 'dynamic' type Body to begin dragging.
        for (body in space.bodiesUnderPoint(mousePoint)) {
            if (!body.isDynamic()) {
                continue;
            }
 
            // Configure hand joint to drag this body.
            //   We initialise the anchor point on this body so that
            //   constraint is satisfied.
            //
            //   The second argument of worldPointToLocal means we get back
            //   a 'weak' Vec2 which will be automatically sent back to object
            //   pool when setting the handJoint's anchor2 property.
            handJoint.body2 = body;
            handJoint.anchor2.set(body.worldPointToLocal(mousePoint, true));
 
            // Enable hand joint!
            handJoint.active = true;
 
            break;
        }
 
        // Release Vec2 back to object pool.
        mousePoint.dispose();
    }
 
    public function mouseUpHandler(ev:MouseEvent):Void {
        // Disable hand joint (if not already disabled).
        handJoint.active = false;
    }
 
    public function keyDownHandler(ev:KeyboardEvent):Void {
        if (ev.keyCode == 82) { // 'R'
            // space.clear() removes all bodies and constraints from
            // the Space.
            space.clear();
 
            setUp();
        }
    }
}


/*
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Circle;
import nape.shape.Polygon;
import nape.space.Space;

class PhysicsTest{
	public var space:Space;

	public var body:Body;

	public var w:Float;
	public var h:Float;

	public function new(w:Float, h:Float){
		this.w = w;
		this.h = h;

		setupWorld();
		createBodies();
	}

	public function setupWorld(){
		space = new Space();//Space(gravity)
	}

	public function createBodies(){
		var border = new Body(BodyType.STATIC);
		border.shapes.add(new Polygon(Polygon.rect(0, 0, w, -1)));
		border.shapes.add(new Polygon(Polygon.rect(0, h, w, 1)));
		border.shapes.add(new Polygon(Polygon.rect(0, 0, -1, h)));
		border.shapes.add(new Polygon(Polygon.rect(w, 0, 1, h)));
		border.space = space;

		for (i in 0...100) {
		    var body = new Body();
		
		    // Add random one of either a Circle, Box or Pentagon.
		    if (Math.random() < 0.33) {
		    	continue;
		        body.shapes.add(new Circle(20));
		    }
		    else if (Math.random() < 0.5) {
		        body.shapes.add(new Polygon(Polygon.box(40, 40)));
		    }
		    else {
		        body.shapes.add(new Polygon(Polygon.regular(20, 20, 5)));
		    }

			body.applyImpulse( Vec2.weak(Math.random()*300-150,Math.random()*300-150) );
		    // Set to random position on stage and add to Space.
		    body.position.setxy(Math.random() * w, Math.random() * h);
		    body.space = space;
		}
	}

	public function step(dt:Float){
		space.step(dt);
	}
}*/