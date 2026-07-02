import config, sys
from datetime import datetime, timedelta
for p in config.PROJECT_PATHS: sys.path.append(p)
from cloud import Cloud
cloud = Cloud()
target = datetime.now() + timedelta(minutes=1)
cloud.db.collection('schedules').document('live_test').set({
    'label': 'LIVE TEST',
    'cat_id': 'cat_001',
    'hour': target.hour,
    'minute': target.minute,
    'portion_g': 30,
    'enabled': True,
    'active_days': [True]*7
})
print(f'Test schedule set for {target.hour:02d}:{target.minute:02d}')
