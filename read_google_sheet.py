# If you have trouble loading, try conda
# I got it working without ncar_pylib
# If you see a [(NPL) ] prompt type deactivate
# 
# But I had to install with conda
# conda install google-api-python-client
# conda install oauth2client
#
# Also 

from googleapiclient.discovery import build
from httplib2 import Http
from oauth2client import file, client, tools

# If modifying these scopes, delete the file token.json.
SCOPES = 'https://www.googleapis.com/auth/spreadsheets.readonly'

# The ID and range of a spreadsheet.
SAMPLE_SPREADSHEET_ID = '1QtxUjO3qIXf2ySPRh0RPG51KasDUCQwmp4ac0hKG3zk'
SAMPLE_RANGE_NAME = 'Sheet1!E5:F19'



idir = '/glade/work/ahijevyc/ADCIRC/'
def main():
    """Shows basic usage of the Sheets API.
    Prints values from a spreadsheet.
    """
    # The file token.json stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    store = file.Storage(idir+'token.json')
    creds = store.get()
    if not creds or creds.invalid:
        flow = client.flow_from_clientsecrets(idir+'credentials.json', SCOPES)
        creds = tools.run_flow(flow, store)
    service = build('sheets', 'v4', http=creds.authorize(Http()))

    # Call the Sheets API
    sheet = service.spreadsheets()
    result = sheet.values().get(spreadsheetId=SAMPLE_SPREADSHEET_ID,
                                range=SAMPLE_RANGE_NAME).execute()
    values = result.get('values', [])
    if not values:
        print('No data found.')
    else:
        print(SAMPLE_RANGE_NAME)
        for row in values:
            print(row)

if __name__ == '__main__':
    main()
