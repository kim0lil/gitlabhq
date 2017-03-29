require 'spec_helper'

describe 'Issues csv', feature: true do
  let(:user) { create(:user) }
  let(:project) { create(:empty_project, :public) }
  let(:milestone) { create(:milestone, title: 'v1.0', project: project) }
  let(:idea_label) { create(:label, project: project, title: 'Idea') }
  let(:feature_label) { create(:label, project: project, title: 'Feature') }
  let!(:issue)  { create(:issue, project: project, author: user) }

  before { login_as(user) }

  def request_csv(params = {})
    visit namespace_project_issues_path(project.namespace, project, params)
    click_on 'Export as CSV'
    click_on 'Export issues'
  end

  def attachment
    ActionMailer::Base.deliveries.last.attachments.first
  end

  def csv
    CSV.parse(attachment.decode_body, headers: true)
  end

  it 'triggers an email export' do
    expect(ExportCsvWorker).to receive(:perform_async).with(user.id, project.id, hash_including(project_id: project.id))

    request_csv
  end

  it "doesn't send request params to ExportCsvWorker" do
    expect(ExportCsvWorker).to receive(:perform_async).with(anything, anything, hash_excluding(controller: anything, action: anything))

    request_csv
  end

  it 'displays flash message' do
    request_csv

    expect(page).to have_content 'CSV export has started'
    expect(page).to have_content "emailed to #{user.notification_email}"
  end

  it 'includes a csv attachment' do
    request_csv

    expect(attachment.content_type).to include('text/csv')
  end

  it 'ignores pagination' do
    create_list(:issue, 30, project: project, author: user)

    request_csv

    expect(csv.count).to eq 31
  end

  it 'uses filters from issue index' do
    request_csv(state: :closed)

    expect(csv.count).to eq 0
  end

  it 'uses array filters, such as label_name' do
    issue.update!(labels: [idea_label])

    request_csv("label_name[]" => 'Bug')

    expect(csv.count).to eq 0
  end

  it 'avoids excessive database calls' do
    control_count = ActiveRecord::QueryRecorder.new{ request_csv }.count
    create_list(:labeled_issue,
                10,
                project: project,
                assignees: [user],
                author: user,
                milestone: milestone,
                labels: [feature_label, idea_label])
    expect{ request_csv }.not_to exceed_query_limit(control_count + 23)
  end
end
