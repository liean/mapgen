// Generate a fantasy-world map
// Author: amitp@cs.stanford.edu
// License: MIT

// redistribute altitudes
   // river carving
     
package {
  import flash.geom.*;
  import flash.display.*;
  import flash.filters.*;

  public class mapgen extends Sprite {
    public static var SEED:int = Math.random() * 50000;
    public static var OCEAN_ALTITUDE:int = 1;
    public static var SIZE:int = 384;
    
    public var altitude:Vector.<Vector.<int>> = make2dArray(SIZE, SIZE);
    public var moisture:Vector.<Vector.<int>> = make2dArray(SIZE, SIZE);
    
    public var map:BitmapData = new BitmapData(SIZE, SIZE);
    
    public function mapgen() {
      stage.scaleMode = "noScale";
      addChild(new Debug(this));
      
      graphics.beginFill(0xaaaa99);
      graphics.drawRect(-1000, -1000, 2000, 2000);
      graphics.endFill();

      generate();
      spreadMoisture();
      // makeRiverChannel();
      
      //carveCanyons();
      
      //spreadMoisture();
      spreadMoisture();
      
      channelsToColors();

      var b:Bitmap = new Bitmap(map);
      b.x = 130;
      b.y = 0;
      b.scaleX = 384.0/SIZE;
      b.scaleY = b.scaleX;
      addChild(b);

      b = new Bitmap(arrayToBitmap(moisture));
      b.x = 0;
      b.y = 0;
      b.scaleX = 128.0/SIZE;
      b.scaleY = b.scaleX;
      addChild(b);

      b = new Bitmap(arrayToBitmap(altitude));
      b.x = 0;
      b.y = 130;
      b.scaleX = 128.0/SIZE;
      b.scaleY = b.scaleX;
      addChild(b);
    }

    public function generate():void {
      // Generate 3-channel perlin noise and copy 2 of the channels out
      var b:BitmapData = new BitmapData(SIZE, SIZE);
      b.perlinNoise(SIZE, SIZE, 8, SEED, false, false);

      equalizeTerrain(b);
      
      var s:Shape = new Shape();
      
      s.graphics.beginFill(0xffffff, 0.1);
      s.graphics.drawCircle(SIZE/2, SIZE/2, SIZE/2);
      s.graphics.endFill();
      b.draw(s);
      
      s.graphics.clear();
      s.graphics.beginFill(0xffffff, 0.1);
      s.graphics.drawRect(10, 10, SIZE-2*10, SIZE-2*10);
      s.graphics.endFill();
      b.draw(s);
      
      equalizeTerrain(b);

      
      // Extract information from bitmap
      for (var x:int = 0; x < SIZE; x++) {
        for (var y:int = 0; y < SIZE; y++) {
          var c:int = b.getPixel(x, y);
          altitude[x][y] = (c >> 8) & 0xff;
          moisture[x][y] = c & 0xff;
        }
      }
    }

    public function equalizeTerrain(b:BitmapData):void {
      // Adjust altitude histogram so that it's roughly quadratic
      var histograms:Vector.<Vector.<Number>> = b.histogram(b.rect);
      var A:Vector.<Number> = histograms[1];
      var k:int = 0;
      var green:Array = new Array(256);
      var cumsum:Number = 0.0;
      for (var i:int = 0; i < 256; i++) {
        cumsum += A[i];
        green[i] = (k*k/256) << 8; // int to green color value
        while (cumsum > SIZE*SIZE*Math.sqrt(k/256.0) && k < 255) {
          k++;
        }
      }
      b.paletteMap(b, b.rect, new Point(0, 0), null, green, null, null);
      
      // Blur everything because the quadratic shift introduces
      // discreteness -- ick!!  TODO: probably better to apply the
      // histogram correction after we convert to the altitude[]
      // array, although even there it's already been discretized :(
      b.applyFilter(b, b.rect, new Point(0, 0), new BlurFilter());
    }
    
    public function make2dArray(w:int, h:int):Vector.<Vector.<int>> {
      var v:Vector.<Vector.<int>> = new Vector.<Vector.<int>>(w);
      for (var x:int = 0; x < w; x++) {
        v[x] = new Vector.<int>(h);
        for (var y:int = 0; y < h; y++) {
          v[x][y] = 0;
        }
      }
      return v;
    }

    public function arrayToBitmap(v:Vector.<Vector.<int>>):BitmapData {
      var b:BitmapData = new BitmapData(SIZE, SIZE, false, 0xff222222);
      for (var x:int = 0; x < SIZE; x++) {
        for (var y:int = 0; y < SIZE; y++) {
          var c:int = v[x][y];
          b.setPixel(x, y, (c << 16) | (c << 8) | c);
        }
      }
      return b;
    }

    public function spreadMoisture():void {
      var windX:Number = 5.0;
      var windY:Number = 2.0;
      
      for (var x:int = 0; x < SIZE; x++) {
        for (var y:int = 0; y < SIZE; y++) {
          if (altitude[x][y] < OCEAN_ALTITUDE) {
            moisture[x][y] = 255; // ocean
          }
          
          var w:Number = Math.random();
          var x2:int = x + int(windX * w);
          var y2:int = y + int(windY * w);
          if (0 <= x2 && x2 < SIZE
              && 0 <= y2 && y2 < SIZE
              && x != x2 && y != y2) {
            var transfer:int = moisture[x][y]/3;
            var speed:Number = (10.0 + altitude[x][y]) / (10.0 + altitude[x2][y2]);
            /* speed is higher if going downhill */
            transfer = int(transfer * speed);
            
            if (transfer + moisture[x2][y2] > 255) {
              transfer = 255 - moisture[x2][y2];
            }
            moisture[x][y] -= transfer;
            moisture[x2][y2] += transfer;
          }
        }
      }
    }

    public function carveCanyons():void {
      var rivers:Vector.<Vector.<int>> = make2dArray(SIZE, SIZE);
      
      for (var iteration:int = 0; iteration < 10000; iteration++) {
        var x:int = int(Math.floor(SIZE*Math.random()));
        var y:int = int(Math.floor(SIZE*Math.random()));

        for (var trail:int = 0; trail < 1000; trail++) {
          // Just quit at the boundaries
          if (x == 0 || x == SIZE-1 || y == 0 || y == SIZE-1) {
            break;
          }

          // Find the minimum neighbor
          var x2:int = x, y2:int = y;
          for (var dx:int = -1; dx <= +1; dx++) {
            for (var dy:int = -1; dy <= +1; dy++) {
              if (altitude[x+dx][y+dy] < altitude[x2][y2]) {
                x2 = x+dx; y2 = y+dy;
              }
            }
          }

          // TODO: make the river keep going to the ocean no matter what!
          
          // Move the particle in that direction, and remove some land
          if (x == x2 && y == y2) {
            if (altitude[x][y] < 10) break;
            altitude[x][y] = Math.min(255, altitude[x][y] + trail);
          }
          x = x2; y = y2;
          // altitude[x][y] = Math.max(0, altitude[x][y] - 1);
          rivers[x][y] += 1;
        }
      }

      for (x = 0; x < SIZE; x++) {
        for (y = 0; y < SIZE; y++) {
          if (rivers[x][y] > 100) moisture[x][y] = 255;
        }
      }
    }
        
    public function makeRiverChannel():void {
      var x:int, y:int;
      var queue:Array = new Array();
      var map:Array = new Array();
      var index:Array = new Array(SIZE);
      var start:int = 0;
      for (x = 0; x < SIZE; x++) {
        index[x] = new Array(SIZE);
        for (y = 0; y < SIZE; y++) {
          index[x][y] = x * SIZE + y;
          var node:Object = {index: index[x][y], x: x, y: y, dist: 1e10,
                             altitude: altitude[x][y], previous: -1};
          map[index[x][y]] = node;
          queue.push(node);
          if (node.altitude < map[start].altitude) {
            start = node.index;
          }
        }
      }
      
      map[start].dist = 0;

      Debug.trace(queue.length);
      
      while (queue.length > 15000) {
        queue.sortOn('dist', Array.NUMERIC | Array.DESCENDING);
        node = queue.pop();
        x = node.x;
        y = node.y;
        for (var dx:int = -1; dx <= +1; dx++) {
          for (var dy:int = -1; dy <= +1; dy++) {
            if ((dx != 0 || dy != 0)
                && 0 <= x+dx && x+dx < SIZE
                && 0 <= y+dy && y+dy < SIZE) {
              var node2:Object = map[index[x+dx][y+dy]];
              var altDist:Number = node.dist + (1 + Math.max(0, node2.altitude - node.altitude));
              if (altDist < node2.dist) {
                node2.dist = altDist;
                node2.previous = node.index;
              }
            }
          }
        }
      }

      for (x = 0; x < SIZE; x++) {
        for (y = 0; y < SIZE; y++) {
          node = map[index[x][y]];
          if (node.previous != -1) {
            node2 = map[node.previous];
            if (node2.altitude < node.altitude) {
              altitude[x][y] = node2.altitude + 1;
              moisture[x][y] = 255;
            }
          }
        }
      }
    }
    
    public function channelsToColors():void {
      for (var x:int = 0; x < SIZE; x++) {
        for (var y:int = 0; y < SIZE; y++) {
          var color:int = 0xff0000;
          
          if (altitude[x][y] < OCEAN_ALTITUDE) color = 0x000099;
          else if (altitude[x][y] > 220) {
            if (altitude[x][y] > 250) color = 0xffffff;
            else if (altitude[x][y] > 240) color = 0xeeeeee;
            else if (altitude[x][y] > 230) color = 0xdddddd;
            else color = 0xcccccc;
            if (moisture[x][y] > 150) color -= 0x331100;
          }
          else if (moisture[x][y] > 240) color = 0x00cc99;
          else if (moisture[x][y] > 200) color = 0x558866;
          else if (moisture[x][y] > 100) color = 0x446633;
          else if (moisture[x][y] > 50) color = 0xaaaa77;
          else color = 0x998855;

          map.setPixel(x, y, color);
        }
      }
    }
  }
}
