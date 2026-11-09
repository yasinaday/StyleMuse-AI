"""Deterministic synthetic mask regressions; no inference or network."""
import unittest
from PIL import Image
from providers import extract_items, tryoff_prompt


def result(category, points, score=.9):
    mask = [[int((x, y) in points) for x in range(12)] for y in range(16)]
    return {'input': {'text': category}, 'scores': [score], 'masks': [mask]}


class IntegrityTests(unittest.TestCase):
    def test_complete_jumpsuit_wins_over_contained_pants_in_either_order(self):
        full = {(x,y) for x in range(3,9) for y in range(2,15) if (x+y)%7}
        legs = {(x,y) for x,y in full if y > 8}
        for rows in ([result('trousers',legs,.99),result('jumpsuit',full,.8)],
                     [result('jumpsuit',full,.8),result('trousers',legs,.99)]):
            self.assertEqual([i['category'] for i in extract_items(Image.new('RGB',(12,16)),rows)],['jumpsuit'])

    def test_pants_alias_has_canonical_category(self):
        points={(1,1),(1,2),(2,2)}
        self.assertEqual(extract_items(Image.new('RGB',(12,16)),[result('pants',points)])[0]['category'],'trousers')

    def test_duplicate_winner_is_confidence_not_input_order(self):
        points={(x,y) for x in range(2,8) for y in range(2,14) if (x+y)%5}
        rows=[result('trousers',points,.6),result('dress',points,.95)]
        self.assertEqual(extract_items(Image.new('RGB',(12,16)),rows)[0]['category'],'dress')

    def test_five_garments_preserve_distinct_masks_without_footwear(self):
        rows=[]
        for n,cat in enumerate(('jumpsuit','dress','jacket','trousers','bag','shoes')):
            points={(n*2,y) for y in range(2,8)}|{(n*2+1,2)}
            rows.append(result(cat,points))
        items = extract_items(Image.new('RGB',(12,16)),rows)
        self.assertEqual({i['category'] for i in items}, {'jumpsuit','dress','jacket','trousers','bag'})
        self.assertEqual(len(items),5)

    def test_layer_overlap_preserves_original_pixels_without_shoes(self):
        import base64
        import io
        photo = Image.new('RGB', (12,16), (23,47,81))
        jacket = {(x,y) for x in range(2,9) for y in range(2,10) if x != 5 or y > 6}
        top = {(x,y) for x in range(4,8) for y in range(3,12) if (x+y)%5}
        left = {(1,13),(1,14),(2,14)}
        right = {(9,13),(9,14),(10,14)}
        items = extract_items(photo,[result('jacket',jacket), result('top',top),
                                    result('shoes',left),result('shoes',right)])
        self.assertEqual(len(items),2)
        self.assertEqual({i['category'] for i in items}, {'jacket', 'top'})
        for item in items:
            image=Image.open(io.BytesIO(base64.b64decode(item['preview'].split(',')[1])))
            for r,g,b,a in (image.getpixel((x,y)) for y in range(image.height) for x in range(image.width)):
                if a:
                    self.assertEqual((r,g,b),(23,47,81))

    def test_separate_pants_not_suppressed_by_unrelated_dress(self):
        dress={(x,y) for x in range(1,5) for y in range(2,15) if (x+y)%5}
        pants={(x,y) for x in range(7,11) for y in range(8,15) if (x+y)%5}
        items=extract_items(Image.new('RGB',(12,16)),[result('dress',dress),result('trousers',pants)])
        self.assertEqual(len(items),2)

    def test_prompts_preserve_visible_construction_without_invented_features(self):
        for category in ('jumpsuit','dress','jacket','trousers','bag'):
            prompt=tryoff_prompt(category)
            for phrase in ('open front','zipper','pockets','lining','accessories','original texture','preserve only markings visibly present'):
                self.assertIn(phrase,prompt)
