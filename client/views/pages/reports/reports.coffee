import { Reports } from '/imports/api/reports/reports.coffee'

defaultText = "<i class='fa fa-spinner fa-pulse'></i>"

fetchData = (thisTemplate) ->
	projectId = FlowRouter.getParam('projectId')
	month = FlowRouter.getQueryParam('month')
	unless month then month = moment(new Date).format('YYYY[M]MM')
	startDate = parseInt moment(month, 'YYYY[M]MM').format('YYYYDDDD')
	endDate = parseInt moment(month, 'YYYY[M]MM').endOf('month').format('YYYYDDDD')

	for field in Object.keys(thisTemplate.basicSums)
		thisTemplate.basicSums[field].set(defaultText)

	Reports.GetAchievementSummary.call
		projectId: projectId
		startDate: startDate
		endDate: endDate
	, (e, result) -> unless e
		delete result._id
		for field in Object.keys(result)
			thisTemplate.basicSums[field].set(result[field])

	for field in Object.keys(thisTemplate.participantsCount)
		thisTemplate.participantsCount[field].set(defaultText)

	Reports.GetParticipantsCount.call
		projectId: projectId
		startDate: startDate
		endDate: endDate
	, (e, result) -> unless e
		for field in Object.keys(result)
			thisTemplate.participantsCount[field].set(result[field])

Template.reports.helpers

	getProjectId: -> FlowRouter.getParam('projectId')

	getMonth: -> FlowRouter.getQueryParam('month')

	readyOrDisabled: ->
		if ShiftSubs.ready()
			button: '', icon: 'fa-download'
		else
			button: 'disabled', icon: 'fa-spinner fa-pulse'

	basicSums: (field) -> Template.instance().basicSums[field].get()

	participantsCount: (field) -> Template.instance().participantsCount[field].get()

Template.reports.onCreated ->

	Template.instance().basicSums =
		texts: new ReactiveVar
		speaks: new ReactiveVar
		videos: new ReactiveVar
		website: new ReactiveVar
		hours: new ReactiveVar
		route: new ReactiveVar
		good: new ReactiveVar
		problems: new ReactiveVar

	Template.instance().participantsCount =
		fulltime: new ReactiveVar
		publishers: new ReactiveVar
		all: new ReactiveVar

	self = this
	projectId = FlowRouter.getParam('projectId')
	month = FlowRouter.getQueryParam('month')

	if !month?
		wrs -> FlowRouter.setQueryParams month: moment(new Date).format('YYYY[M]MM')
		month = moment(new Date).format('YYYY[M]MM')

	Session.set 'subscribe', month
	@autorun ->
		if Session.get 'subscribe'
			ShiftSubs.subscribe 'reports', projectId, Session.get 'subscribe'
			Session.set 'subscribe', false

Template.reports.onRendered ->

	$('.animated').removeClass('animated').addClass('skipping')

	thisTemplate = Template.instance()

	fetchData(thisTemplate)

Template.reports.events

	'click #prevMonth': ->
		prevMonth = moment(FlowRouter.getQueryParam('month'), 'YYYY[M]MM').subtract(1, 'M').format('YYYY[M]MM')
		thisTemplate = Template.instance()
		Session.set 'subscribe', prevMonth
		wrs ->
			FlowRouter.setQueryParams month: prevMonth
			fetchData(thisTemplate)

	'click #nextMonth': ->
		nextMonth = moment(FlowRouter.getQueryParam('month'), 'YYYY[M]MM').add(1, 'M').format('YYYY[M]MM')
		thisTemplate = Template.instance()
		Session.set 'subscribe', nextMonth
		wrs ->
			FlowRouter.setQueryParams month: nextMonth
			fetchData(thisTemplate)

	'click #showMissing': -> false

	'click #showExperiences': (e) ->
		type = $(e.target).attr('type')

	'click #exportReports': ->
		projectId = FlowRouter.getParam('projectId')
		month = FlowRouter.getQueryParam('month')

		if month?
			csvContent = 'data:text/csv;charset=utf-8,' + '\uFEFF'
			head = []
			[
				'modal.shiftReport.date'
				'shifts.start'
				'shifts.end'
				'shifts.shift.tag'
				'modal.editShift.team'
				'reports.meetingStart'
				'reports.meetingEnd'
				'reports.place'
				'modal.shiftReport.teamleader'
				'reports.participants'
				'modal.shiftReport.texts'
				'modal.shiftReport.speaks'
				'modal.shiftReport.videos'
				'modal.shiftReport.website'
				'modal.shiftReport.returnVisits'
				'modal.shiftReport.bibleStudies'
				'modal.shiftReport.time'
				'modal.shiftReport.trolleysFilled'
				'modal.shiftReport.neatnessLast'
				'modal.shiftReport.expRoute'
				'modal.shiftReport.expGood'
				'modal.shiftReport.expProblems'
				'modal.shiftReport.publications'
			].map (c) -> head.push TAPi18n.__(c)

			csvContent += head.join(';') + '\r\n'

			firstDay = parseInt moment(month, 'YYYY[M]MM').format('YYYYDDDD')
			lastDay = parseInt moment(month, 'YYYY[M]MM').endOf('month').format('YYYYDDDD')

			shifts = Shifts.find
				projectId: projectId
				$and: [
					date: $gte: firstDay
				,
					date: $lte: lastDay
				]
			,
				sort: date: 1, start: 1, end: 1

			for shift in shifts.fetch()
				for team in shift.teams
					row = []
					row.push moment(shift.date, 'YYYYDDDD').format('YYYY-MM-DD')
					row.push moment(shift.start, 'Hmm').format('HH:mm')
					row.push moment(shift.end, 'Hmm').format('HH:mm')
					row.push shift.tag
					row.push team.name
					row.push team.meetingStart?.name
					row.push team.meetingEnd?.name
					row.push team.place?.name
					row.push team.participants.filter((p) -> p.thisTeamleader)[0]?.name.trim()
					row.push team.participants.filter((p) -> !p.thisTeamleader).map((p) ->
						if p.state in ['sick', 'missing']
							p.name.trim() + ' (' + TAPi18n.__('modal.shiftReport.' + p.state) + ')'
						else
							p.name.trim()
					).join(', ')

					if team.report? && team.report.items?
						row.push team.report.texts, team.report.speaks, team.report.videos, team.report.website, team.report.returnVisits, team.report.bibleStudies, team.report.hours, team.report.filled, team.report.neatness

						route = team.report.experiences.route || ''
						good = team.report.experiences.good || ''
						problems = team.report.experiences.problems || ''

						row.push route.replace(/(?:\\[rn]|[\r\n]+)+/g, ' ')
						row.push good.replace(/(?:\\[rn]|[\r\n]+)+/g, ' ')
						row.push problems.replace(/(?:\\[rn]|[\r\n]+)+/g, ' ')

						for item in team.report.items
							row.push item.count + ' ' + item.short + '-' + item.language

					csvContent += row.join(';') + '\r\n'

			encodedUri = encodeURI(csvContent)
			link = document.createElement('a')
			link.setAttribute('href', encodedUri)
			link.setAttribute('target', 'blank')
			link.setAttribute('download', 'reports.csv')
			document.body.appendChild(link)
			link.click()
