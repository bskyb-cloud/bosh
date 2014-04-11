package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/action"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
)

func init() {
	Describe("GetTask", func() {
		var (
			taskService *faketask.FakeService
			action      GetTaskAction
		)

		BeforeEach(func() {
			taskService = faketask.NewFakeService()
			action = NewGetTask(taskService)
		})

		It("is synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("returns a running task", func() {
			taskService.StartedTasks["fake-task-id"] = boshtask.Task{
				Id:    "fake-task-id",
				State: boshtask.TaskStateRunning,
			}

			taskValue, err := action.Run("fake-task-id")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `{"agent_task_id":"fake-task-id","state":"running"}`)
		})

		It("returns a failed task", func() {
			taskService.StartedTasks["fake-task-id"] = boshtask.Task{
				Id:    "fake-task-id",
				State: boshtask.TaskStateFailed,
				Error: errors.New("fake-task-error"),
			}

			taskValue, err := action.Run("fake-task-id")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), "fake-task-error", err.Error())
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `null`)
		})

		It("returns a successful task", func() {
			taskService.StartedTasks["fake-task-id"] = boshtask.Task{
				Id:    "fake-task-id",
				State: boshtask.TaskStateDone,
				Value: "some-task-value",
			}

			taskValue, err := action.Run("fake-task-id")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `"some-task-value"`)
		})

		It("returns error when task is not found", func() {
			taskService.StartedTasks = map[string]boshtask.Task{}

			_, err := action.Run("fake-task-id")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), "Task with id fake-task-id could not be found", err.Error())
		})
	})
}
