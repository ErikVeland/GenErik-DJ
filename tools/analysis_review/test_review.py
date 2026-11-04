import unittest
import review

class ReviewTests(unittest.TestCase):
    def test_song_titles_do_not_claim_version_types(self):
        for title in ['Live Your Life', 'Radio Ga Ga', 'Dub Be Good To Me', 'Club Can\'t Handle Me']:
            with self.subTest(title=title):
                self.assertEqual(review.hints({'title': title, 'genre': 'Pop'})[1], ['unspecified'])

    def test_explicit_version_types_are_retained(self):
        for title,want in [('Song (12" Mix)', '12-inch'), ("Song (12'' Main Mix)", '12-inch'),
                           ('Song (12_ Mix)', '12-inch'), ('Song (Extended Mix)', 'extended'), ('Song (Live at Wembley)', 'live'),
                           ('Song (Vamp Dub Mix)', 'dub'), ('Song - Radio Edit', 'radio-edit')]:
            with self.subTest(title=title):
                self.assertIn(want,review.hints({'title': title})[1])

    def test_related_versions_share_the_same_test_split(self):
        tracks=[{'id':str(i),'title':title,'genre':'House'} for i,title in enumerate(['Song', 'Song (Radio Edit)', 'Song (Extended Mix)'])]
        selected=review.select(tracks,3)
        self.assertEqual(len({t['songFamily'] for t in selected}),1)
        self.assertEqual(len({t['split'] for t in selected}),1)

    def test_common_genres_do_not_displace_small_genres(self):
        tracks=[{'id':str(i),'title':f'Song {i}','genre':'House'} for i in range(100)]
        tracks.append({'id':'rare','title':'Ambient piece','genre':'Ambient'})
        selected=review.select(tracks,2)
        self.assertEqual({t['genreFamilyHint'] for t in selected},{'house-disco','ambient-downtempo'})

if __name__=='__main__': unittest.main()
