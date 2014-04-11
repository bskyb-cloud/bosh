package task_test

import (
	"errors"
	"fmt"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/task"
	boshlog "bosh/logger"
	fakeuuid "bosh/uuid/fakes"
)

func init() {
	Describe("asyncTaskService", func() {
		var (
			uuidGen *fakeuuid.FakeGenerator
			service Service
		)

		BeforeEach(func() {
			uuidGen = &fakeuuid.FakeGenerator{}
			service = NewAsyncTaskService(uuidGen, boshlog.NewLogger(boshlog.LEVEL_NONE))
		})

		Describe("StartTask", func() {
			startAndWaitForTaskCompletion := func(task Task) Task {
				service.StartTask(task)
				for task.State == TaskStateRunning {
					time.Sleep(time.Nanosecond)
					task, _ = service.FindTaskWithId(task.Id)
				}
				return task
			}

			It("sets return value on a successful task", func() {
				runFunc := func() (interface{}, error) { return 123, nil }

				task, err := service.CreateTask(runFunc, nil)
				Expect(err).ToNot(HaveOccurred())

				task = startAndWaitForTaskCompletion(task)
				Expect(task.State).To(BeEquivalentTo(TaskStateDone))
				Expect(task.Value).To(Equal(123))
				Expect(task.Error).To(BeNil())
			})

			It("sets task error on a failing task", func() {
				err := errors.New("fake-error")
				runFunc := func() (interface{}, error) { return nil, err }

				task, createErr := service.CreateTask(runFunc, nil)
				Expect(createErr).ToNot(HaveOccurred())

				task = startAndWaitForTaskCompletion(task)
				Expect(task.State).To(BeEquivalentTo(TaskStateFailed))
				Expect(task.Value).To(BeNil())
				Expect(task.Error).To(Equal(err))
			})

			Describe("CreateTask", func() {
				It("can run task created with CreateTask which does not have end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					task, err := service.CreateTask(runFunc, nil)
					Expect(err).ToNot(HaveOccurred())

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
				})

				It("can run task created with CreateTask which has end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					ranEndFunc := false
					endFunc := func(Task) { ranEndFunc = true }

					task, err := service.CreateTask(runFunc, endFunc)
					Expect(err).ToNot(HaveOccurred())

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
					Expect(ranEndFunc).To(BeTrue())
				})

				It("returns an error if generate uuid fails", func() {
					uuidGen.GenerateError = errors.New("fake-generate-uuid-error")
					_, err := service.CreateTask(nil, nil)
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-generate-uuid-error"))
				})
			})

			Describe("CreateTaskWithId", func() {
				It("can run task created with CreateTaskWithId which does not have end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					task := service.CreateTaskWithId("fake-task-id", runFunc, nil)

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
				})

				It("can run task created with CreateTaskWithId which has end func", func() {
					ranFunc := false
					runFunc := func() (interface{}, error) { ranFunc = true; return nil, nil }

					ranEndFunc := false
					endFunc := func(Task) { ranEndFunc = true }

					task := service.CreateTaskWithId("fake-task-id", runFunc, endFunc)

					startAndWaitForTaskCompletion(task)
					Expect(ranFunc).To(BeTrue())
					Expect(ranEndFunc).To(BeTrue())
				})
			})

			It("can process many tasks simultaneously", func() {
				taskFunc := func() (interface{}, error) {
					time.Sleep(10 * time.Millisecond)
					return nil, nil
				}

				ids := []string{}
				for id := 1; id < 200; id++ {
					idStr := fmt.Sprintf("%d", id)
					uuidGen.GeneratedUuid = idStr
					ids = append(ids, idStr)

					task, err := service.CreateTask(taskFunc, nil)
					Expect(err).ToNot(HaveOccurred())
					go service.StartTask(task)
				}

				for {
					allDone := true
					for _, id := range ids {
						task, _ := service.FindTaskWithId(id)
						if task.State != TaskStateDone {
							allDone = false
							break
						}
					}

					if allDone {
						break
					}
					time.Sleep(200 * time.Millisecond)
				}
			})
		})

		Describe("CreateTask", func() {
			It("creates a task with auto-assigned id", func() {
				uuidGen.GeneratedUuid = "fake-uuid"

				runFunc := func() (interface{}, error) { return nil, nil }
				endFunc := func(Task) {}

				task, err := service.CreateTask(runFunc, endFunc)
				Expect(err).ToNot(HaveOccurred())
				Expect(task.Id).To(Equal("fake-uuid"))
				Expect(task.State).To(Equal(TaskStateRunning))
			})
		})

		Describe("CreateTaskWithId", func() {
			It("creates a task with given id", func() {
				runFunc := func() (interface{}, error) { return nil, nil }
				endFunc := func(Task) {}

				task := service.CreateTaskWithId("fake-task-id", runFunc, endFunc)
				Expect(task.Id).To(Equal("fake-task-id"))
				Expect(task.State).To(Equal(TaskStateRunning))
			})
		})
	})
}
